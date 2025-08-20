---

## **[The Master Guide] 2025 사이버보안 제1과제 최종 공략집**

### **Mission Briefing: 작전 개요**

파트너, 이전의 모든 기억은 삭제되었습니다. 지금부터 우리는 이 문서 하나만으로 모든 과제를 해결합니다. 각 미션은 채점 기준과 직접 연결되어 있으며, 모든 명령어와 설정값이 포함되어 있습니다. 지시에 따라 정확하게 임무를 수행해주시기 바랍니다.

---

### **Mission 1: 기반 구축 - 서버 네트워크 설정**

**🎯 목표:** `server` VM이 과제에서 요구하는 고정 IP 주소를 갖도록 설정합니다. (채점 항목 1-1)

1.  **`server` VM 고정 IP 설정:**
    *   `server` VM에 `kolo_user` 계정으로 로그인합니다.
    *   💡 **팁:** 설정 전 `ip a` 명령으로 자신의 인터페이스 이름(예: `ens33`)을 먼저 확인하세요.
    *   터미널에서 아래 명령을 실행하여 Netplan 설정 파일을 엽니다.
        ```bash
        sudo nano /etc/netplan/01-network-manager-all.yaml
        ```
    *   기존 내용을 모두 지우고 아래 내용으로 변경합니다. (VMware Host-only 네트워크 기본 게이트웨이는 보통 `.1`입니다.)
        ```yaml
        network:
          version: 2
          renderer: networkd
          ethernets:
            ens33: # 확인한 실제 인터페이스 이름으로 변경
              dhcp4: no
              addresses: [192.168.127.129/24]
              gateway4: 192.168.127.1
              nameservers:
                addresses: [8.8.8.8]
        ```
    *   저장(`Ctrl+O`, `Enter`) 후 종료(`Ctrl+X`)하고, 아래 명령어로 설정을 적용합니다.
        ```bash
        sudo netplan apply
        ```

2.  **✅ 확인:**
    *   `ifconfig ens33` (또는 `ip a show ens33`) 명령어로 `inet 192.168.127.129`가 설정되었는지 확인합니다.
    *   `HOST` PC의 CMD 창에서 `ping 192.168.127.129`를 실행하여 통신이 되는지 확인합니다.

---

### **Mission 2: 독립 환경 구축 - Docker 네트워크 및 컨테이너 생성**

**🎯 목표:** `www`와 `kolodb`가 독립적으로 동작할 Docker 환경을 구축합니다. (채점 항목 1-2)

1.  **Docker 네트워크 생성:**
    *   `server` VM 터미널에서 `www`와 `kolodb`가 서로 통신할 격리된 네트워크를 생성합니다.
        ```bash
        sudo docker network create --subnet=192.168.127.0/24 kolo-net
        ```

2.  **기존 MariaDB 데이터베이스 백업 (마이그레이션 준비):**
    *   기존 `server`에서 운영 중인 게시판 DB(`midsv`)를 백업 파일(`midsv_backup.sql`)로 만듭니다.
        ```bash
        sudo mysqldump -u root -p midsv > midsv_backup.sql
        ```
    *   패스워드를 물어보면 `KoloSecu@)25`를 입력합니다.

3.  **`kolodb` (MariaDB) 컨테이너 생성 및 DB 복원 (항목 3):**
    *   MariaDB Docker 이미지를 사용하여 `kolodb` 컨테이너를 생성합니다.
        ```bash
        sudo docker run -d \
        --name kolodb \
        --network kolo-net \
        --ip 192.168.127.10 \
        -e MARIADB_ROOT_PASSWORD=user01 \
        --restart always \
        -p 3306:3306 \
        mariadb
        ```
    *   생성한 백업 파일을 실행 중인 `kolodb` 컨테이너 내부로 복사합니다.
        ```bash
        sudo docker cp midsv_backup.sql kolodb:/midsv_backup.sql
        ```
    *   `kolodb` 컨테이너에 접속하여 백업 파일을 복원합니다.
        ```bash
        sudo docker exec -it kolodb bash
        # --- 지금부터는 컨테이너 내부 ---
        mariadb -u root -puser01 -e "CREATE DATABASE midsv;"
        mariadb -u root -puser01 midsv < midsv_backup.sql
        exit
        # --- 컨테이너에서 빠져나옴 ---
        ```

4.  **`www` (Tomcat) 컨테이너 생성 (항목 4):**
    *   Tomcat Docker 이미지를 사용하여 `www` 컨테이너를 생성합니다. `server`에 있는 웹 애플리케이션(`jboard.war` 또는 유사한 이름)을 컨테이너로 복사해야 합니다.
    *   💡 **팁:** 웹 애플리케이션 파일의 위치는 `/var/lib/tomcat9/webapps/` 아래에 있을 가능성이 높습니다. `ROOT.war` 와 같은 이름일 수 있습니다.
        ```bash
        sudo docker run -d \
        --name www \
        --network kolo-net \
        --ip 192.168.127.20 \
        --restart always \
        -p 8080:8080 \
        -v /var/lib/tomcat9/webapps/jboard.war:/usr/local/tomcat/webapps/ROOT.war \
        tomcat:9
        ```
    *   **[중요]** `www`의 DB 연결 정보를 `kolodb`로 변경해야 합니다. 이는 웹 애플리케이션 내의 설정 파일(예: `WEB-INF/classes/db.properties`)을 수정해야 하는 과정이며, 과제에서는 이미지가 사전 구성되어 있을 가능성이 높습니다. 만약 수동 수정이 필요하다면, 컨테이너 생성 전 원본 `.war` 파일의 압축을 풀어 수정 후 다시 압축하거나, 컨테이너 실행 후 `docker exec`로 접속하여 수정해야 합니다.

---

### **Mission 3: 최종 검증 - 채점 기준 시뮬레이션**

**🎯 목표:** 채점관의 입장에서 모든 요구사항이 완벽하게 동작하는지 최종 확인합니다.

1.  **✅ 서버 및 컨테이너 구성 확인 (항목 1):**
    *   `ifconfig` 또는 `ip a`: `ens33`에 `192.168.127.129`가 설정되어 있는지 확인.
    *   `sudo docker ps`: `www`와 `kolodb` 컨테이너가 `Up` 상태로 실행 중인지 확인.

2.  **✅ 네트워크 연결 확인 (항목 2):**
    *   **`HOST` PC의 CMD 창**에서 아래 3개의 ping 테스트를 모두 수행합니다.
        ```cmd
        ping 192.168.127.129  # server 연결
        ping 192.168.127.20   # www 연결
        ping 192.168.127.10   # kolodb 연결
        ```
    *   **Expected Result:** 세 테스트 모두 손실 없이(0% loss) 성공해야 합니다.

3.  **✅ MariaDB 이전 확인 (항목 3):**
    *   `server` 터미널에서 `kolodb` 컨테이너에 접속하여 DB 목록을 확인합니다.
        ```bash
        sudo docker exec -it kolodb mariadb -u root -puser01
        # --- 컨테이너 내부 MariaDB 접속 ---
        show databases;
        ```
    *   **Expected Result:** `midsv` 데이터베이스가 목록에 보여야 합니다.
    *   `server`의 로컬 MariaDB에도 접속하여 동일하게 `show databases;`를 실행하고, 두 목록이 동일한지 확인합니다.

4.  **✅ 서비스 동작 및 독립성 확인 (항목 4-1, 4-2):**
    1.  **웹 페이지 접속:** `HOST` PC의 웹 브라우저에서 아래 두 주소로 각각 접속합니다.
        *   `http://192.168.127.129:8080` (server 게시판)
        *   `http://192.168.127.20:8080` (www 게시판)
    2.  **Expected Result:** 두 페이지 모두 동일한 초기 게시물 목록을 가진 '2025 SECURE BOARD'가 보여야 합니다.
    3.  **독립성 테스트:**
        *   `server` 게시판(`...129:8080`)에서 "게시글 추가하기"를 눌러 **"로컬 DB 테스트"** 라는 글을 작성합니다.
        *   `www` 게시판(`...20:8080`) 탭으로 이동하여 `Ctrl+F5`로 새로고침합니다.
    4.  **Expected Result:** `www` 게시판에는 **"로컬 DB 테스트" 글이 보이지 않아야 합니다.**
        *   반대로 `www` 게시판에 **"도커 DB 테스트"** 글을 작성하고 `server` 게시판을 새로고침했을 때도 글이 보이지 않아야 합니다.

5.  **✅ 자동 실행 확인 (항목 4-3):**
    1.  `server` VM을 재부팅합니다: `sudo reboot`
    2.  재부팅 완료 후 다시 로그인하여 Docker 컨테이너 상태를 확인합니다.
        ```bash
        sudo docker ps
        ```
    3.  **Expected Result:** `www`와 `kolodb` 컨테이너가 별도 조치 없이 자동으로 실행되어 `Up` 상태여야 합니다.
    4.  `HOST` PC 브라우저에서 `http://192.168.127.20:8080`에 접속하여, 이전에 작성했던 **"도커 DB 테스트"** 글이 그대로 남아있는지 확인합니다.

---
