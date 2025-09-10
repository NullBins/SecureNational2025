---

# 🛡 사이버 보안 *Cyber Security* 🔐
## 🖋 *Written by **Donghyun Choi*** (**KGU**)
###### ⚔ - Worldskills Korea ▫ National 2025 (Cyber Security Practices) - 🏹 [ *Written by NullBins* ]
- By default, the commands are executed as a root user.

# [ *Project-1* ] <*🌐Infrastructure configuration & Security enhancements💠*>

---

## 1. 네트워크 구성 (Network Configuration)
- *🎯 기반 구축 - 서버 네트워크 설정* `VM 고정 IP주소 설정 및 독립적으로 동작할 Docker 네트워크 구축.`
### < *Configuration* >
- [ server ] -> Virtual Machine
```vim
mv /etc/netplan/*.yaml /etc/netplan/config.yaml
```
```vim
nano /etc/netplan/config.yaml
```
>```yaml
>network:
>  ethernets:
>    ens33:
>      addresses: [192.168.127.129/24]
>      routes:
>        - to: default
>          via: 192.168.127.1
>      dhcp4: false
>  renderer: networkd
>  version: 2
>```
```vim
netplan apply
docker network create -d macvlan --subnet 192.168.127.0/24 --gateway 192.168.127.1 -o parent=ens33 kolo-net
```
```vim
nano /etc/rc.local
```
>```vim
>#!/bin/bash
>
>sysctl --system
># Virtual Network Bridge
>ip link add kolo-net-host link ens33 type macvlan mode bridge
>ip addr add 192.168.127.254/24 dev kolo-net-host
>ip link set kolo-net-host up
>ip route add 192.168.127.10/32 dev kolo-net-host
>ip route add 192.168.127.20/32 dev kolo-net-host
>ip addr show kolo-net-host | grep inet
>ip route show | grep kolo-net
>
>exit 0
>```
```vim
chmod +x /etc/rc.local
systemctl restart rc-local
```
### < *Checking* >
- [ server ] : VM
```vim
docker network ls
ip addr show kolo-net-host
```

## 2. KoloDB 컨테이너 구성 (DB Server Container Configuration)
- *🎯 독립 환경 구축 - Docker DB 컨테이너 구성* `기존 MariaDB 백업 및 Migration 진행.`
### < *Configuration* >
- [ server ] : VM
```vim
nano /etc/mysql/conf.d/mysql.cnf
```
>```ini
>[mysqld]
>lower_case_table_names=1
>```
```vim
mysqldump -u root -p midsv > ./midsv_backup.sql
mysqldump -u root -p mysql_bk > ./mysql_bk_backup.sql
docker tag mariadb:latest mariadb:kolo
docker run -d --name kolodb --hostname kolodb --restart always --network kolo-net --ip 192.168.127.10 -e MARIADB_ROOT_PASSWORD=user01 -v /etc/mysql/conf.d/mysql.cnf:/etc/mysql/conf.d/custom.cnf mariadb:kolo
mariadb -h 192.168.127.10 -u root -puser01 -e "grant all privileges on *.* to 'dbroot'@'%' identified by 'asd123'"
mariadb -h 192.168.127.10 -u root -puser01 -e 'flush privileges'
mariadb -h 192.168.127.10 -u root -puser01 -e 'create database midsv'
mariadb -h 192.168.127.10 -u root -puser01 -e 'create database mysql_bk'
mariadb -h 192.168.127.10 -u root -puser01 midsv < ./midsv_backup.sql
mariadb -h 192.168.127.10 -u root -puser01 mysql_bk < ./mysql_bk_backup.sql
```
### < *Checking* >
- [ server ] : VM
```vim
docker ps -a
mariadb -h 192.168.127.10 -u root -puser01 midsv -e 'select * from board'
```

## 3. WWW 컨테이너 구성 (Web Server Container Configuration)
- *🎯 독립 환경 구축 - Docker Web 컨테이너 구성* `기존 Web Service 백업 및 Migration 진행.`
### < *Configuration* >
- [ server ] : VM
```vim
grep -r "3306" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/
sed -i "s/localhost/192.168.127.10/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/spring/root-context.xml
sed -i "s/localhost/192.168.127.10/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/classes/config/value.properties
/home/kolo_user/apache-tomcat-9.0.89/bin/shutdown.sh
/home/kolo_user/apache-tomcat-9.0.89/bin/startup.sh
cd /home/kolo_user/
```
```vim
nano Dockerfile
```
>```vim
>FROM tomcat:9.0
>COPY ./apache-tomcat-9.0.89/ /usr/local/tomcat/
>```
```vim
docker build -t tomcat:kolo .
docker run -d --name www --hostname www --restart always --network kolo-net --ip 192.168.127.20 tomcat:kolo
sed -i "s/192.168.127.10/localhost/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/spring/root-context.xml
sed -i "s/192.168.127.10/localhost/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/classes/config/value.properties
/home/kolo_user/apache-tomcat-9.0.89/bin/shutdown.sh
/home/kolo_user/apache-tomcat-9.0.89/bin/startup.sh
```
### < *Checking* >
- [ server ] : VM
```vim
docker ps -a
curl -I http://192.168.127.20:8080
```
- [ HOST ] -> Host Desktop PC
```powershell
ping -4 -n 1 192.168.127.129
ping -4 -n 1 192.168.127.254
ping -4 -n 1 192.168.127.10
ping -4 -n 1 192.168.127.20
curl -I http://192.168.127.20:8080
```

---

## ✅ 요약 (Summary)
- *Shell script code* : `Set all assignment items.`
```vim
#!/bin/bash
## ----------------------------------------------------------------------- ##
docker network create -d macvlan --subnet 192.168.127.0/24 --gateway 192.168.127.1 -o parent=ens33 kolo-net
nano /etc/rc.local
# --- #
#!/bin/bash
sysctl --system
# Virtual Network Bridge
ip link add kolo-net-host link ens33 type macvlan mode bridge
ip addr add 192.168.127.254/24 dev kolo-net-host
ip link set kolo-net-host up
ip route add 192.168.127.10/32 dev kolo-net-host
ip route add 192.168.127.20/32 dev kolo-net-host
ip addr show kolo-net-host | grep inet
ip route show | grep kolo-net
exit 0
# --- #
chmod +x /etc/rc.local
systemctl restart rc-local
nano /etc/mysql/conf.d/mysql.cnf
# --- #
[mysqld]
lower_case_table_names=1
# --- #
mysqldump -u root -p midsv > ./midsv_backup.sql
mysqldump -u root -p mysql_bk > ./mysql_bk_backup.sql
docker tag mariadb:latest mariadb:kolo
docker run -d --name kolodb --hostname kolodb --restart always --network kolo-net --ip 192.168.127.10 -e MARIADB_ROOT_PASSWORD=user01 -v /etc/mysql/conf.d/mysql.cnf:/etc/mysql/conf.d/custom.cnf mariadb:kolo
mariadb -h 192.168.127.10 -u root -puser01 -e "grant all privileges on *.* to 'dbroot'@'%' identified by 'asd123'"
mariadb -h 192.168.127.10 -u root -puser01 -e 'flush privileges'
mariadb -h 192.168.127.10 -u root -puser01 -e 'create database midsv'
mariadb -h 192.168.127.10 -u root -puser01 -e 'create database mysql_bk'
mariadb -h 192.168.127.10 -u root -puser01 midsv < ./midsv_backup.sql
mariadb -h 192.168.127.10 -u root -puser01 mysql_bk < ./mysql_bk_backup.sql
grep -r "3306" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/
sed -i "s/localhost/192.168.127.10/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/spring/root-context.xml
sed -i "s/localhost/192.168.127.10/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/classes/config/value.properties
/home/kolo_user/apache-tomcat-9.0.89/bin/shutdown.sh
/home/kolo_user/apache-tomcat-9.0.89/bin/startup.sh
cd /home/kolo_user/
nano Dockerfile
# --- #
FROM tomcat:9.0
COPY ./apache-tomcat-9.0.89/ /usr/local/tomcat/
# --- #
docker build -t tomcat:kolo .
docker run -d --name www --hostname www --restart always --network kolo-net --ip 192.168.127.20 tomcat:kolo
sed -i "s/192.168.127.10/localhost/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/spring/root-context.xml
sed -i "s/192.168.127.10/localhost/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/classes/config/value.properties
/home/kolo_user/apache-tomcat-9.0.89/bin/shutdown.sh
/home/kolo_user/apache-tomcat-9.0.89/bin/startup.sh
## ----------------------------------------------------------------------- ##
```

---
