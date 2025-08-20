# 2025 전국기능경기대회 사이버보안 제2과제

**주제:** 네트워크 보안 장비 설정(UTM/OPNsense + Router + WireGuard + WAF + DVWA)

> 이 문서는 공개과제를 토대로 실제 대회 당일 변형을 감안해 **모든 설정(Configuration)을 끝까지 재현**할 수 있도록 **리눅스 명령어 + 설정파일 값**을 **순서대로** 정리한 실전 가이드입니다. 재부팅 제한(총 3회)을 고려해 **무부팅-적용**을 우선합니다.

---

## 0) 전체 토폴로지 & 주소 요약

* **네트워크 대역**

  * INSIDE: `192.168.1.0/24`
  * DMZ: `210.111.10.128/25`
  * OUTSIDE(Internet): `210.111.10.0/25`
  * MOBILITY: `203.150.10.0/24`
* **핵심 IP**

  * **Router (Ubuntu)**: OUTSIDE `210.111.10.1/25`, MOBILITY `203.150.10.254/24`, **Default GW** `203.150.10.1`
  * **UTM (OPNsense)**:

    * OUTSIDE(WAN): `210.111.10.120/25` GW `210.111.10.1`
    * DMZ: `210.111.10.129/25`
    * INSIDE(LAN): **`192.168.1.1/24`** *(공개문서 표에서 `192.168.1.10`로 보일 수 있으나 서버와 충돌·DHCP 기본GW와 불일치 → 실전은 `192.168.1.1` 사용 권장)*
  * **서버(server, Ubuntu)**: `192.168.1.10/24`, GW `192.168.1.1`
  * **웹(www, Ubuntu)**: `210.111.10.150/25`, GW `210.111.10.129`
  * **공격자(attacker, Kali)**: `210.111.10.35/25`, GW `210.111.10.1`
  * **모바일(mobile, Ubuntu)**: `203.150.10.100/24`, GW `203.150.10.254`
* **VPN(SSL/WireGuard)**: `10.2.43.0/24` (UTM: `10.2.43.1`, Mobile: `10.2.43.10` 예시)
* **WAF**: UTM 상의 **Nginx(+ModSecurity/CRS)** 역방향 프록시로 구성, **WAN(210.111.10.120:80)** 에서 수신 → **DMZ www(210.111.10.150:80)** 로 프록시

---

## 1) 공통 사전 작업 (모든 Ubuntu/Kali)

> 사용자 계정: `bob_user`(Ubuntu들), `kali`(Kali). 관리자 권한은 `sudo -i` 권장.

### 1-1. 호스트명 설정

```bash
sudo hostnamectl set-hostname <client|server|www|router|mobile|attacker>
```

### 1-2. IPv6 비활성화(영구)

```bash
sudo tee /etc/sysctl.d/99-disable-ipv6.conf >/dev/null <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sudo sysctl --system
```

### 1-3. 스크린 세이버/잠금 비활성화(Desktop 세션)

```bash
# GNOME idle/lock 해제
sudo -u ${SUDO_USER:-$USER} gsettings set org.gnome.desktop.session idle-delay 0
sudo -u ${SUDO_USER:-$USER} gsettings set org.gnome.desktop.screensaver lock-enabled false

# 전원절약 화면꺼짐 방지(있으면)
sudo -u ${SUDO_USER:-$USER} gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0 || true
```

### 1-4. NIC 식별 팁

```bash
ip -br a        # 인터페이스와 연결된 VMware VMnet 식별
nmcli dev show  # udev명 확인
```

---

## 2) 네트워크 설정 (netplan)

> Ubuntu 22.04 기준. 인터페이스명은 예시(`ens33`, `ens34`)이며 실제 값으로 치환.

### 2-1. client (INSIDE, DHCP)

```bash
sudo tee /etc/netplan/01-client.yaml >/dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:          # INSIDE 연결 NIC
      dhcp4: true
      dhcp6: false
EOF
sudo netplan apply
ip a
ip r
```

### 2-2. server (INSIDE, 고정 IP + 아웃바운드 차단 대상)

```bash
sudo tee /etc/netplan/01-server.yaml >/dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      addresses: [192.168.1.10/24]
      routes:
        - to: 0.0.0.0/0
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8]
      dhcp6: false
EOF
sudo netplan apply
```

### 2-3. www (DMZ, 고정 IP)

```bash
sudo tee /etc/netplan/01-www.yaml >/dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:   # DMZ 연결 NIC
      addresses: [210.111.10.150/25]
      routes:
        - to: 0.0.0.0/0
          via: 210.111.10.129   # UTM DMZ IP
      nameservers:
        addresses: [8.8.8.8]
      dhcp6: false
EOF
sudo netplan apply
```

### 2-4. attacker (OUTSIDE, 고정 IP)

```bash
sudo tee /etc/netplan/01-attacker.yaml >/dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      addresses: [210.111.10.35/25]
      routes:
        - to: 0.0.0.0/0
          via: 210.111.10.1   # Router OUTSIDE IP
      nameservers:
        addresses: [8.8.8.8]
      dhcp6: false
EOF
sudo netplan apply
```

### 2-5. mobile (MOBILITY, 고정 IP + WireGuard 클라이언트)

```bash
sudo tee /etc/netplan/01-mobile.yaml >/dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      addresses: [203.150.10.100/24]
      routes:
        - to: 0.0.0.0/0
          via: 203.150.10.254   # Router MOBILITY IP
      nameservers:
        addresses: [8.8.8.8]
      dhcp6: false
EOF
sudo netplan apply
```

### 2-6. router (이중 NIC: OUTSIDE + MOBILITY, 정적 라우팅)

```bash
sudo tee /etc/netplan/01-router.yaml >/dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:   # OUTSIDE
      addresses: [210.111.10.1/25]
      dhcp4: false
      dhcp6: false
    ens34:   # MOBILITY
      addresses: [203.150.10.254/24]
      dhcp4: false
      dhcp6: false
  routes:
    # 디폴트: MOBILITY쪽 가상 GW로
    - to: 0.0.0.0/0
      via: 203.150.10.1
    # DMZ 네트워크로 가는 정적 경로(다음 홉: UTM의 OUTSIDE IP)
    - to: 210.111.10.128/25
      via: 210.111.10.120
EOF
sudo netplan apply

# IP 포워딩 활성화(영구)
sudo tee /etc/sysctl.d/99-router-forward.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
```

---

## 3) UTM(OPNsense 25.1) 설정

> 콘솔/웹UI 기반. 플러그인(nginx, modsecurity, wireguard)은 배포 이미지에 포함됐다고 가정. 재부팅 없이 대부분 적용 가능.

### 3-1. 인터페이스/주소

* **Interfaces → Assignments**

  * **WAN(OUTSIDE)**: `210.111.10.120/25`, **Gateway** `210.111.10.1`
  * **DMZ**: `210.111.10.129/25`
  * **LAN(INSIDE)**: **`192.168.1.1/24`**

### 3-2. 시스템 전역

* **System → Settings → General**

  * IPv6 관련 기능 비활성(Prefer IPv4, IPv6 off)
* **Firewall → Settings → Advanced**

  * **Block IPv6** 체크
* **Services → DHCPv4 → LAN**

  * 범위: `192.168.1.100 - 192.168.1.200`
  * 기본 게이트웨이: `192.168.1.1`
  * DNS 서버: 필요시 지정(예: `8.8.8.8`)

### 3-3. NAT

* **Firewall → NAT → Outbound**

  * 모드: **Hybrid**
  * 규칙1(일반 내부 NAT):

    * Interface: **WAN**
    * Source: `192.168.1.0/24` **except** `192.168.1.10/32`(server 제외)
    * Translation / Address: **`210.111.10.120`**
  * 규칙2(서버 비NAT):

    * Interface: **WAN/DMZ**
    * Source: `192.168.1.10/32`
    * Translation: **NO NAT** (또는 `Disable NAT` 동등 옵션)

### 3-4. 방화벽 규칙(모든 규칙 **Log** 활성)

* **Floating 또는 각 인터페이스 상단에 IPv6 Drop**

  * Action: **Block**, IPv6 **any-any**
* **ICMP 허용(전역)**

  * 각 인터페이스에 `IPv4 ICMP any-any` **Pass**
* **LAN(INSIDE) → DMZ**

  * **허용**: `TCP 80(HTTP)` + `ICMP`
  * **차단(우선순위 상단)**: server(`192.168.1.10`) → DMZ **any**
* **LAN(INSIDE) → OUTSIDE/MOBILITY**

  * **허용**: `IPv4 *` (단, server는 아래 규칙으로 제한)
* **LAN(server) 예외**

  * **차단**: server(`192.168.1.10`) → OUTSIDE **any**
  * **차단**: server(`192.168.1.10`) → DMZ **any**
  * **허용**: server(`192.168.1.10`) ↔ **WireGuard 대역 `10.2.43.0/24`**
* **WAN 수신(OUTSIDE)**

  * **허용**: `TCP 80` → **This firewall** (Nginx 프록시용)
  * **허용**: `UDP 51820` → **This firewall** (WireGuard)
  * **차단**: OUTSIDE → DMZ **직접** 접근(예: `DMZ net any` 명시 Block)
* **DMZ →** (기본 정책 최소화, 필요 트래픽만 허용)

  * DMZ → WAN 기본 차단, DMZ → LAN 기본 차단(과제 요구 외 불필요 트래픽 방지)

### 3-5. WAF (Nginx + ModSecurity/CRS)

* **Services → Nginx → Upstreams**

  * Name: `dmz_www_pool`
  * Server: `210.111.10.150:80`
* **Services → Nginx → HTTP(S) → Server**

  * Name: `waf_www`
  * Listen Interface: **WAN(210.111.10.120)**
  * Listen Port: **80**
  * Locations: `/` → Upstream `dmz_www_pool`
  * **Enable ModSecurity** + **CRS 활성화**, **Mode: Block**
  * (선택) Custom Deny page: 간단한 차단 문구 작성(한글 OK)
* **Firewall 연계**: 위의 **WAN:80 → This firewall** 허용 규칙이 반드시 필요. OUTSIDE/MOBILITY에서 **DMZ www 직접 접근**은 방화벽에서 **차단**. INSIDE는 **직접**(DMZ IP로) 또는 **WAF 경유** 모두 허용 상태.

### 3-6. WireGuard(SSL VPN)

* **VPN → WireGuard**

  * **Local(UTM)**

    * Name: `wg0`
    * Listen Port: `51820`
    * Tunnel Address: `10.2.43.1/24`
  * **Peer(mobile)**

    * Public Key: *(mobile에서 생성한 키)*
    * Allowed IPs: `10.2.43.10/32`
    * Endpoint: *(로밍/공인IP 불명 → 공란, Persistent keepalive 25s 권장)*
* **Firewall**

  * **WAN**: `UDP/51820` 허용(위에서 설정)
  * **WireGuard 인터페이스 그룹** 생성 후, `WG → LAN(server)`/`LAN(server) → WG` 상호 허용
* **Routes**

  * `10.2.43.0/24`는 WireGuard 인터페이스에 로컬로 존재 → 별도 정적 라우팅 불필요. 단, LAN에서 WG로의 정책 허용 필수.

---

## 4) www 서버(DVWA) 준비 (DMZ)

> 배포물에 Docker 구성이 포함되어 있다고 가정.

```bash
sudo systemctl enable --now docker || true
# 폴더에 compose 파일이 있다면
cd ~/dvwa || cd ~/www || cd ~/DVWA || pwd
# 예: docker compose (또는 docker-compose)
docker compose up -d

# 확인
docker ps
# DVWA 컨테이너 포트가 80로 뜨는지 확인
ss -lntp | grep :80
```

> 방화벽 요구사항상 OUTSIDE/MOBILITY는 **UTM WAF(210.111.10.120:80)** 로만 접속 가능. INSIDE는 `210.111.10.150`(직접) 또는 `210.111.10.120`(WAF) 모두 가능해야 함.

---

## 5) mobile(클라이언트) WireGuard 설정

### 5-1. 키 생성

```bash
sudo -i
umask 077
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
cat /etc/wireguard/public.key   # → 값을 UTM Peer 설정에 등록
```

### 5-2. 클라이언트 설정파일(`/etc/wireguard/wg0.conf`)

```ini
[Interface]
Address = 10.2.43.10/24
PrivateKey = <mobile-private-key>
# 필요 시 DNS 지정
# DNS = 192.168.1.1

[Peer]
PublicKey = <UTM-public-key>
Endpoint = 210.111.10.120:51820   # UTM WAN
AllowedIPs = 10.2.43.1/32, 192.168.1.0/24
PersistentKeepalive = 25
```

### 5-3. 가동/부팅연동

```bash
sudo systemctl enable --now wg-quick@wg0
ip a show wg0
ping -c2 10.2.43.1
ping -c2 192.168.1.10  # INSIDE server와 통신되어야 함
```

---

## 6) 검증 시나리오(필수)

### 6-1. ICMP 전면 허용 확인

* `client/server/www/router/mobile/attacker` 각 호스트에서 상호 **ping** 정상.

### 6-2. INSIDE → DMZ 제약

```bash
# client(INSIDE) → www(DMZ)
curl -I http://210.111.10.150   # 200 OK 기대
ping -c2 210.111.10.150         # 성공

# server(INSIDE) → DMZ/OUTSIDE는 차단되어야 함
curl -I http://210.111.10.150   # 실패 기대(방화벽 로그 체크)
curl -I http://210.111.10.1     # 실패 기대
```

### 6-3. OUTSIDE/MOBILITY → www 직접 접속 차단 + WAF 경유 허용

```bash
# attacker(OUTSIDE): DMZ 직접 접속 → 차단되어야 함
curl -I http://210.111.10.150   # 실패

# WAF 경유
curl -I http://210.111.10.120   # 200/301 등 프록시 응답
```

### 6-4. WAF 차단 테스트(명령주입)

```bash
# DVWA의 Command Injection 페이지 예시(로그인/보안레벨 조정 후)
# 공격 페이로드 예: ;id 또는 && id 등
curl "http://210.111.10.120/vulnerabilities/exec/?ip=127.0.0.1;id&Submit=Submit#"
# → ModSecurity 차단 페이지/403 확인
```

### 6-5. MOBILITY(mobile) VPN 검증

```bash
# mobile에서
ping -c2 10.2.43.1       # UTM WG 터널
ping -c2 192.168.1.10    # INSIDE server

# server에서 VPN 대역과 통신 허용 확인(다른 외부는 차단 유지)
ping -c2 10.2.43.10
```

---

## 7) VMware VMnet 관련 주의(요구사항 반영)

* **VMnet 목록에서 문제에 없는 VMnet 제거**
* **HOST1의 VMnet DHCP 기능 전부 비활성**
* **OUTSIDE는 각 HOST의 NIC를 브리지**
* **HOST2는 SW1(실물)과 물리 1개 케이블만 연결**

> 위 항목은 VMware Virtual Network Editor에서 처리. 적용 후 각 VM NIC가 올바른 VMnet에 연결되었는지 재검증.

---

## 8) 트러블슈팅 & 로그 체크포인트

* **OPNsense 방화벽 로그**: 모든 정책에 **Log** 활성했으므로 상단 매치 여부 확인.
* **Nginx/ModSecurity 로그**: 차단 이벤트(rule id/phase) 확인, 필요 시 false-positive 룰 예외 추가(단, 과제 범위 내에서 명령주입은 차단되도록 유지).
* **WireGuard**: `wg show`에서 핸드셰이크/전송 바이트 확인. AllowedIPs 양끝 일치 필수.
* **라우팅**: router에 `ip r`로 `210.111.10.128/25 via 210.111.10.120` 존재 확인.

---

## 9) 재부팅 제한 하 최적 적용 순서(권장)

1. 모든 Ubuntu/Kali: IPv6 off → netplan 적용 → 스크린세이버 off (무부팅)
2. Router: 라우팅/포워딩 적용(무부팅)
3. UTM: 인터페이스/게이트웨이 → DHCP(LAN) → NAT/Rules → WAF(Nginx) → WG(VPN)
4. www: Docker DVWA 가동
5. 최종 검증 시나리오 실행

---

## 10) 대회 당일 변형 대비 포인트

* INSIDE/LAN 게이트웨이 IP가 변형되면 **server DHCP/GW** 값과 **DHCPv4 옵션** 동시 수정.
* OUTSIDE/MOBILITY 포트나 주소가 바뀌면 **router 정적경로**와 **UTM WAN GW** 재정의.
* WAF 포트(예: 8080)로 바꾸면 **WAN:8080 허용** 및 **Nginx Listen 포트** 동시 변경.
* VPN 대역이 변경되면 `AllowedIPs`, 방화벽 예외, server ↔ WG 허용 규칙을 같이 수정.

---

### 부록 A) 즉시 복사용 스니펫(요청 많은 것만)

**IPv6 영구 차단 공통 스니펫**

```bash
sudo tee /etc/sysctl.d/99-disable-ipv6.conf >/dev/null <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sudo sysctl --system
```

**Router 정적경로 재적용**

```bash
sudo ip route replace 210.111.10.128/25 via 210.111.10.120 dev ens33
```

**WireGuard 서비스**

```bash
sudo systemctl enable --now wg-quick@wg0
sudo systemctl restart wg-quick@wg0
```

**Nginx 재적용(OPNsense 웹UI에서 Apply)**

* Services → Nginx → Configuration Test → Apply

---

> ✅ 이 문서만으로 **과제 전 항목**(IPv6 차단, ICMP 허용, INSIDE↔DMZ 정책, OUTSIDE/MOBILITY 접근, DHCP, NAT, WAF, WireGuard, Router 경로/포워딩)을 **명령어/설정 값**까지 재현할 수 있습니다.
