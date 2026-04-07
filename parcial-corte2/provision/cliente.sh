#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  net-tools \
  iputils-ping \
  traceroute \
  dnsutils \
  ftp \
  lftp \
  openssl \
  curl \
  wget \
  tcpdump


mkdir -p /etc/systemd

cat > /etc/systemd/resolved.conf <<'EOF'
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=1.0.0.1 8.8.4.4
DNSOverTLS=yes
DNSSEC=no
EOF

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

systemctl restart systemd-resolved
systemctl enable systemd-resolved

echo "Provision cliente completado con DNS over TLS."
