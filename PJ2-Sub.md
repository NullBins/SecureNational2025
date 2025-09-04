---

## **[The Final Master Guide] 2025 사이버보안 제2과제 최종 공략집**

### **Mission Briefing: 작전 개요**

파트너, 지금부터 우리는 이 문서 하나만으로 모든 과제를 해결합니다. 각 미션은 채점 항목과 직접 연결되어 있으며, 모든 명령어와 설정값이 포함되어 있습니다. 지시에 따라 정확하게 임무를 수행해주시기 바랍니다.

---

### **Mission 1: 기반 구축 - 가상 환경 및 시스템 기본 설정**

**🎯 목표:** 채점의 기초가 되는 물리/가상 네트워크 환경을 구축하고, 모든 VM의 상태를 통일합니다. (채점 항목 1-1, 1-2)

1.  **VMware Virtual Network Editor 설정:**
    *   VMware `Edit > Virtual Network Editor` 실행 (`Change Settings` 관리자 권한 클릭).
    *   `VMnet0(Bridged)`, `VMnet1(Host-only)`, `VMnet10(Host-only)` 3개만 남기고 모두 제거합니다.
    *   ⚠️ **[0점 방지] DHCP 서비스 비활성화:**
        *   `VMnet1` 선택 -> **`Use local DHCP service...` 체크 해제!**
        *   `VMnet10` 선택 -> **`Use local DHCP service...` 체크 해제!**
    *   설정 저장 후, 각 VM의 네트워크 어댑터를 과제 도면에 맞게 연결합니다.

2.  **모든 VM 공통 초기 설정:**
    *   **호스트 이름 변경:** `sudo hostnamectl set-hostname [머신이름]` (예: `client`)
    *   **IPv6 비활성화:** 터미널에 아래 명령 실행.
        ```bash
        echo 'net.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf
        echo 'net.ipv6.conf.default.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf
        echo 'net.ipv6.conf.lo.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p
        ```
    *   **화면 보호기 제거 (Ubuntu):** `sudo apt-get remove -y gnome-screensaver`

---

### **Mission 2: 지휘부 설정 - UTM (OPNsense) 핵심 구성**

**🎯 목표:** 네트워크의 두뇌 역할을 할 UTM의 인터페이스, 라우팅, DHCP, 기본 방화벽/NAT를 구성합니다. (채점 항목 2)

1.  **인터페이스 및 게이트웨이 설정 (항목 2-1, 2-2):**
    *   ⚠️ **[실격 방지]** IP 주소와 Prefix(/24, /25)가 하나라도 다르면 실격입니다. 채점 기준표의 **192.168.1.1**이 정확한 값입니다.
    *   웹 GUI 접속 후 **Interfaces > [각 인터페이스]**
        *   **LAN:** `192.168.1.1/24`
        *   **WAN:** `210.111.10.120/25`
        *   **DMZ:** `210.111.10.129/25`
    *   **System > Gateways > Single:** `+ Add`
        *   **Interface:** `WAN`, **Gateway:** `210.111.10.1`, **Default Gateway 체크** 후 저장.

2.  **DHCP 서버 설정 (항목 2-2):**
    *   **Services > DHCPv4 > [LAN]:** `Enable` 체크, **Range:** `192.168.1.100` ~ `192.168.1.199` 설정.

---

### **Mission 3: 유닛 전개 - 개별 VM 네트워크 설정 (전체)**

**🎯 목표:** 각 VM에 고정 IP와 라우팅 경로를 완벽하게 부여합니다. (채점 항목 3-1 ~ 3-6)

💡 **팁:** 설정 전 `ip a` 명령으로 자신의 인터페이스 이름(예: `ens33`)을 먼저 확인하세요.

*   **client (항목 3-1):** DHCP 자동 설정이므로 별도 작업 없음.
    *   ✅ **확인:** 터미널에서 `ip a | grep ens` (192.168.1.1xx IP 확인), `ip r` (default via 192.168.1.1 확인)

*   **server (항목 3-2):** `sudo nano /etc/netplan/01-network-manager-all.yaml`
    ```yaml
    network:
      version: 2
      renderer: networkd
      ethernets:
        ens33: # 실제 인터페이스 이름으로 변경
          dhcp4: no
          addresses: [192.168.1.10/24]
          gateway4: 192.168.1.1
          nameservers:
            addresses: [8.8.8.8]
    ```
    *   `sudo netplan apply`로 적용.

*   **www (항목 3-3):** `sudo nano /etc/netplan/01-network-manager-all.yaml`
    ```yaml
    network:
      version: 2
      renderer: networkd
      ethernets:
        ens33: # 실제 인터페이스 이름으로 변경
          dhcp4: no
          addresses: [210.111.10.150/25]
          gateway4: 210.111.10.129
          nameservers:
            addresses: [8.8.8.8]
    ```
    *   `sudo netplan apply`로 적용.

*   **mobile (항목 3-6):** `sudo nano /etc/netplan/01-network-manager-all.yaml`
    ```yaml
    network:
      version: 2
      renderer: networkd
      ethernets:
        ens33: # 실제 인터페이스 이름으로 변경
          dhcp4: no
          addresses: [203.150.10.100/24]
          gateway4: 203.150.10.254
          nameservers:
            addresses: [8.8.8.8]
    ```
    *   `sudo netplan apply`로 적용.

*   **router (항목 3-4):**
    1.  `sudo nano /etc/netplan/01-network-manager-all.yaml`
        ```yaml
        network:
          version: 2
          renderer: networkd
          ethernets:
            ens33: # OUTSIDE 인터페이스
              dhcp4: no
              addresses: [210.111.10.1/25]
              routes:
                - to: 210.111.10.128/25
                  via: 210.111.10.120
            ens36: # MOBILITY 인터페이스
              dhcp4: no
              addresses: [203.150.10.254/24]
              routes:
                - to: default
                  via: 203.150.10.1
        ```
    2.  IP 포워딩 활성화: `/etc/sysctl.conf`에서 `#net.ipv4.ip_forward=1`의 주석 `#`을 제거하고 `sudo sysctl -p` 실행.
    3.  ✅ **확인:** `ip r` 실행 시 채점표와 동일한 라우팅 테이블이 보이는지 확인.

*   **attacker (항목 3-5):** (Kali Linux NetworkManager GUI 사용 권장)
    *   `연결 편집` -> `유선 연결` -> `IPv4 설정` 탭
    *   **방식:** `수동`
    *   **주소:** `210.111.10.35`, **넷마스크:** `255.255.255.128`, **게이트웨이:** `210.111.10.1` 입력 후 저장.
    *   ✅ **확인:** `ifconfig` (IP 확인), `netstat -rn` (게이트웨이 확인)

---

### **Mission 4: 고급 작전 - ACL, VPN, WAF 구현**

**🎯 목표:** UTM의 핵심 보안 기능인 방화벽(ACL), VPN, WAF를 완벽하게 구성합니다. (채점 항목 4, 5, 6)

1.  **ACL 및 NAT 설정 (항목 4):**
    *   **Firewall > NAT > Outbound:** `Hybrid` 모드 선택 후, **Source** `LAN net`이 **Translation** `WAN address`로 변환되는 수동 규칙 추가. (모든 규칙 생성 시 **Log** 옵션 체크 필수)
    *   **Firewall > Rules > LAN:** (규칙 순서가 매우 중요합니다. 드래그하여 순서를 맞추세요.)
        1.  **[Pass] server -> SSL VPN 대역 허용 (예외 규칙):**
            *   Action: `Pass`, Source: `192.168.1.10`, Destination: `10.2.43.0/24`
        2.  **[Block] server -> 외부 전체 차단:**
            *   Action: `Block`, Source: `192.168.1.10`, Destination: `any`
    *   **Firewall > Rules > WAN:**
        *   **[Pass] ICMP 허용 (ping 테스트용):**
            *   Action: `Pass`, Protocol: `ICMP`, Source: `any`, Destination: `any`
        *   **[Block] 외부 -> www 웹 직접 접속 차단:**
            *   Action: `Block`, Protocol: `TCP/UDP`, Source: `any`, Destination: `210.111.10.150`, Destination Port: `80`

2.  **WireGuard VPN 설정 (항목 5-1, 5-2):**
    1.  **`mobile`에서 키 생성:**
        ```bash
        wg genkey | tee privatekey | wg pubkey > publickey
        ```
        `cat publickey` 명령으로 출력된 공개키를 복사합니다.
    2.  **UTM (서버) 설정:**
        *   **VPN > WireGuard > Local:** `+` 클릭, **Tunnel Address:** `10.2.43.1/24` 설정.
        *   **VPN > WireGuard > Endpoints:** `+` 클릭, **Name:** `mobile`, **Allowed IPs:** `10.2.43.2/32`, **Public Key:** 란에 `mobile`에서 복사한 공개키 붙여넣기.
        *   **방화벽 규칙:** **Firewall > Rules > WAN**에서 UDP/51820 트래픽 허용, **Firewall > Rules > WireGuard**에서 모든 트래픽 허용 규칙 추가.
    3.  **`mobile` (클라이언트) 설정 완료:** `sudo nano /etc/wireguard/wg0.conf`
        ```ini
        [Interface]
        PrivateKey = # cat privatekey 로 확인한 mobile의 개인키
        Address = 10.2.43.2/32

        [Peer]
        PublicKey = # UTM WireGuard Local 탭에서 확인한 공개키
        Endpoint = 210.111.10.120:51820
        AllowedIPs = 192.168.1.0/24
        ```

3.  **WAF & Reverse Proxy 설정 (항목 6-1, 6-2):**
    *   **UTM Nginx 플러그인 (Services > Nginx):**
        1.  `Enable Nginx` 체크.
        2.  **Upstream > Server:** `www` 서버(`210.111.10.150:80`) 등록.
        3.  **Upstream > Location:** `/` 경로와 위 Upstream 연결.
        4.  **HTTP(S) > HTTP Server:** `Listen Address: 210.111.10.120:80`, 위 Location 연결, **WAF 정책 활성화**.
    *   **포트 포워딩 (Firewall > NAT > Port Forward):**
        *   `+ Add`: **Interface:** `WAN`, **Destination:** `WAN address`, **Dest. Port:** `HTTP`, **Redirect IP:** `210.111.10.120` (자신), **Redirect Port:** `HTTP`.
        *   ⚠️ **[핵심] NAT reflection: `Enable (Use system default)`** 로 설정합니다.

---

### **Mission 5: 최종 검증 - 채점 시뮬레이션**

**🎯 목표:** 채점관의 입장에서 모든 요구사항이 완벽하게 동작하는지 최종 확인합니다.

1.  **✅ client ACL 및 NAT (항목 4-1):**
    *   **Action:** `client`에서 `mobile`로 ping.
    *   **Command:** (`client`에서) `ping 203.150.10.100 -c 2`
    *   **Expected Result:** 성공 (0% packet loss)
    *   **Verification:** (`mobile`에서) `sudo tcpdump -n icmp`
    *   **Expected Verification:** `210.111.10.120 > 203.150.10.100` 패킷 확인.

2.  **✅ server ACL (항목 4-2):**
    *   **Action:** `server`에서 `attacker`로 ping.
    *   **Command:** (`server`에서) `ping 210.111.10.35 -c 2`
    *   **Expected Result:** 실패 (100% packet loss)
    *   **Verification:** UTM `Firewall > Log Files > Live View`에서 해당 통신이 **Block** (빨간색 X 아이콘) 되는지 확인.

3.  **✅ www ACL (항목 4-3):**
    *   **Action:** `attacker`에서 `www`로 ping.
    *   **Command:** (`attacker`에서) `ping 210.111.10.150 -c 2`
    *   **Expected Result:** 성공 (ICMP는 허용했기 때문)
    *   **Action:** `attacker`에서 `www`로 웹 접속.
    *   **Command:** (`attacker` 브라우저에서) `http://210.111.10.150`
    *   **Expected Result:** 실패 (Connection timed out)
    *   **Verification:** UTM `Firewall > Log Files`에서 이 웹 접속이 **Block**되는지 확인.

4.  **✅ mobile VPN 동작 (항목 5-2):**
    *   **Action:** `mobile`에서 VPN 연결 후 `server`로 ping.
    *   **Command:** (`mobile`에서) `sudo wg-quick up wg0`, 이후 `ping 192.168.1.10 -c 2`
    *   **Expected Result:** 성공 (0% packet loss)
    *   **Verification:** (`server`에서) `sudo tcpdump -n icmp`
    *   **Expected Verification:** 출발지 IP가 VPN 대역인 `10.2.43.2`로 확인.

5.  **✅ WAF 공격 시나리오 (항목 6-1, 6-2):**
    1.  **[사전준비] `attacker`에서 DVWA 보안 레벨 설정:**
        *   `attacker`의 웹 브라우저로 `http://210.111.10.120` (WAF IP)에 접속합니다.
        *   ID: `admin`, PW: `password` 로 로그인합니다.
        *   왼쪽 메뉴에서 **`DVWA Security`**를 클릭합니다.
        *   Security Level을 **`Low`**로 변경하고 `Submit` 버튼을 클릭합니다.
    2.  **`client`에서 공격 성공 확인 (WAF 우회):**
        *   `client`의 웹 브라우저로 `http://210.111.10.150` (www 실제 IP)에 접속하여 동일하게 로그인 및 보안 레벨을 `Low`로 설정합니다.
        *   **`Command Injection`** 메뉴로 이동하여 IP 입력 칸에 `127.0.0.1 && ls -l` 을 입력하고 `Submit`합니다.
        *   `ping` 결과와 함께 디렉터리 목록(`index.php` 등)이 출력되는 **공격 성공 화면**을 확인합니다.
    3.  **`attacker`에서 공격 차단 확인 (WAF 동작):**
        *   **`attacker`**의 웹 브라우저(WAF IP로 접속된 상태)에서 똑같이 **`Command Injection`** 메뉴로 이동합니다.
        *   IP 입력 칸에 동일한 공격 구문 `127.0.0.1 && ls -l` 을 입력하고 `Submit`합니다.
        *   **"Request Denied For Security Reasons"** 이라는 OPNsense 차단 페이지가 나타나는지 확인합니다.

---
