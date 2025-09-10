#!/bin/bash
# -------------------------- #
nano /etc/hosts
nano /etc/ssh/sshd_config
# --- #
Port 22
PermitRootLogin yes
# --- #
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
nano /etc/rc.local
# --- #
#!/bin/bash
sysctl --system
# --- #
chmod +x /etc/rc.local
systemctl restart rc-local
# -------------------------- #
