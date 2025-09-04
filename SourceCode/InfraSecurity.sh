#!/bin/bash
docker network create -d macvlan --subnet 192.168.127.0/24 --gateway 192.168.127.1 -o parent=ens33 kolo-net
docker network ls
touch /etc/rc.local
chmod +x /etc/rc.local
nano /etc/rc.local
---
#!/bin/bash
# Virtual Network Bridge
ip link add kolo-net-host link ens33 type macvlan mode bridge
ip addr add 192.168.127.254/24 dev kolo-net-host
ip link set kolo-net-host
ip route add 192.168.127.10/32 dev kolo-net-host
ip route add 192.168.127.20/32 dev kolo-net-host
exit 0
---
systemctl enable rc-local
systemctl restart rc-local
ip addr show kolo-net-host
mysqldump -u root -p --no-data midsv > midsv_schema.sql
mysqldump -u root -p --no-create-info midsv > midsv_data.sql
mysqldump -u root -p mysql_bk > ./mysql_bk_backup.sql
docker tag mariadb:latest mariadb:kolo
docker run -d --name kolodb --hostname kolodb --restart always --network kolo-net --ip 192.168.127.10 -e MARIADB_ROOT_PASSWORD=user01 mariadb:kolo
mariadb -h 192.168.127.10 -u root -puser01 -e "grant all privileges on *.* to 'dbroot'@'%' identified by 'asd123'"
mariadb -h 192.168.127.10 -u root -puser01 -e 'flush privileges'
mariadb -h 192.168.127.10 -u root -puser01 -e 'create database midsv'
mariadb -h 192.168.127.10 -u root -puser01 -e 'create database mysql_bk'
mariadb -h 192.168.127.10 -u root -puser01 midsv < ./midsv_schema.sql
mariadb -h 192.168.127.10 -u root -puser01 midsv < ./midsv_data.sql
mariadb -h 192.168.127.10 -u root -puser01 mysql_bk < /mysql_bk_backup.sql
grep -r "localhost" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/
sed -i "s/localhost/192.168.127.10/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/spring/root-context.xml
sed -i "s/localhost/192.168.127.10/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/classes/config/value.properties
/home/kolo_user/apache-tomcat-9.0.89/bin/shutdown.sh
/home/kolo_user/apache-tomcat-9.0.89/bin/startup.sh
mkdir ./tomcat-build; cd ./tomcat-build
cp -r /home/kolo_user/apache-tomcat-9.0.89/ ./
nano Dockerfile
---
FROM tomcat:9.0
COPY ./apache-tomcat-9.0.89/ /usr/local/tomcat/
---
docker build -t tomcat:kolo .
docker run -d --name www --hostname www --restart always --network kolo-net --ip 192.168.127.20 tomcat:kolo
