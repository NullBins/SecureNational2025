#!/bin/bash
# -------------------------- #
passwd root
poweroff
apt update -y
apt install vim net-tools dnsutils tcpdump curl lynx wget ssh tcptraceroute traceroute psmisc sudo util-linux-extra -y
vim /etc/vim/vimrc
vim /etc/hosts
vim /etc/ssh/sshd_config
Port 22
PermitRootLogin yes
systemctl enable ssh
systemctl restart ssh
timedatectl set-timezone Asia/Seoul
hwclock -w
tee /etc/sysctl.d/99-sysctl-apply.conf > /dev/null << EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
sysctl --system
# -------------------------- #
