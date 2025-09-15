#!/bin/bash
## ----------------------------------------------------------------------- ##
docker network create -d macvlan --subnet 192.168.127.0/24 --gateway 192.168.127.1 -o parent=ens33 kolo-net
nano /etc/rc.local > /dev/null << EOF
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
EOF
chmod +x /etc/rc.local
systemctl restart rc-local
mysqldump -u root -p midsv > ./midsv_backup.sql
mysqldump -u root -p mysql_bk > ./mysql_bk_backup.sql
docker tag mariadb:latest mariadb:kolo
docker run -d --name kolodb --hostname kolodb --restart always --network kolo-net --ip 192.168.127.10 -e MARIADB_ROOT_PASSWORD=user01 mariadb:kolo --lower_case_table_names=1
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
tee Dockerfile > /dev/null << EOF
FROM tomcat:9.0
COPY ./apache-tomcat-9.0.89/ /usr/local/tomcat/
EOF
docker build -t tomcat:kolo .
sed -i "s/192.168.127.10/localhost/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/spring/root-context.xml
sed -i "s/192.168.127.10/localhost/g" /home/kolo_user/apache-tomcat-9.0.89/webapps/midsv/WEB-INF/classes/config/value.properties
/home/kolo_user/apache-tomcat-9.0.89/bin/shutdown.sh
/home/kolo_user/apache-tomcat-9.0.89/bin/startup.sh
docker run -d --name www --hostname www --restart always --network kolo-net --ip 192.168.127.20 tomcat:kolo
## ----------------------------------------------------------------------- ##
