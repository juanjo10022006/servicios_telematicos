#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SLAVE_IP="192.168.56.11"

apt-get update -y
apt-get install -y dnsutils curl

# Usar esclavo como DNS
systemctl disable --now systemd-resolved >/dev/null 2>&1 || true

cat >/etc/resolv.conf <<EOF
nameserver ${SLAVE_IP}
search empresa.local
EOF

