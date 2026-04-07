#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ufw \
  net-tools \
  iptables \
  iputils-ping \
  traceroute \
  curl \
  wget \
  openssh-server \
  tcpdump

systemctl enable ssh
systemctl start ssh


sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p


sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw


ufw --force reset


ufw default deny incoming
ufw default allow outgoing


ufw allow 21/tcp
ufw allow 22/tcp
ufw allow 50000:50010/tcp


cat > /etc/ufw/before.rules <<'EOF'
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

# FTPS control
-A PREROUTING -p tcp -d 192.168.50.3 --dport 21 -j DNAT --to-destination 192.168.50.2:21
-A POSTROUTING -p tcp -d 192.168.50.2 --dport 21 -j MASQUERADE

# FTPS pasivo
-A PREROUTING -p tcp -d 192.168.50.3 --dport 50000:50010 -j DNAT --to-destination 192.168.50.2
-A POSTROUTING -p tcp -d 192.168.50.2 --dport 50000:50010 -j MASQUERADE

# SFTP / SSH
-A PREROUTING -p tcp -d 192.168.50.3 --dport 22 -j DNAT --to-destination 192.168.50.2:22
-A POSTROUTING -p tcp -d 192.168.50.2 --dport 22 -j MASQUERADE

COMMIT

*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]
:ufw-not-local - [0:0]

-A ufw-before-input -i lo -j ACCEPT
-A ufw-before-output -o lo -j ACCEPT
-A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

COMMIT
EOF


ufw --force enable

echo "Servidor1 provisionado correctamente."