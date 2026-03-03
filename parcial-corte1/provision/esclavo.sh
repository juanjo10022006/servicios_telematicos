#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ===== Variables =====
DOMAIN_LOCAL="empresa.local"
DOMAIN_PUBLIC="juanjo.com"
MASTER_IP="192.168.56.10"
REV_ZONE="56.168.192.in-addr.arpa"

TSIG_NAME="empresa-transfer"
TSIG_FILE="/etc/bind/keys.${TSIG_NAME}.key"

# ===== Paquetes =====
apt-get update -y
apt-get install -y bind9 bind9utils dnsutils

# ===== Bind9 seguro =====
cat >/etc/bind/named.conf.options <<'EOF'
options {
  directory "/var/cache/bind";

  recursion no;
  allow-recursion { none; };

  listen-on { any; };
  allow-query { any; };

  dnssec-validation auto;
};
EOF

# ===== TSIG (se copia desde maestro) =====
# Para que sea 100% automático en Vagrant: se lee por SSH desde maestro
apt-get install -y openssh-client >/dev/null

# Intentar traer la key desde maestro si no existe
if [ ! -f "${TSIG_FILE}" ]; then
  # Espera corta a que maestro esté arriba
  sleep 5 || true
  # Copia por ssh
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@${MASTER_IP} \
    "sudo cat ${TSIG_FILE}" | tee "${TSIG_FILE}" >/dev/null || true

  chown root:bind "${TSIG_FILE}" || true
  chmod 640 "${TSIG_FILE}" || true
fi

# Mensaje de error si no se pudo obtener la key
if [ ! -s "${TSIG_FILE}" ]; then
  echo "ERROR: No se pudo obtener ${TSIG_FILE} desde el maestro (${MASTER_IP})."
  echo "Solución: entra a maestro y copia el contenido de /etc/bind/keys.${TSIG_NAME}.key a este archivo."
  exit 1
fi

# ===== named.conf.local (zonas esclavo) =====
cat >/etc/bind/named.conf.local <<EOF
include "${TSIG_FILE}";

server ${MASTER_IP} {
  keys { "${TSIG_NAME}"; };
};

zone "${DOMAIN_LOCAL}" {
  type slave;
  masters { ${MASTER_IP} key "${TSIG_NAME}"; };
  file "/var/cache/bind/slave.db.${DOMAIN_LOCAL}";
};

zone "${REV_ZONE}" {
  type slave;
  masters { ${MASTER_IP} key "${TSIG_NAME}"; };
  file "/var/cache/bind/slave.db.192.168.56";
};

zone "${DOMAIN_PUBLIC}" {
  type slave;
  masters { ${MASTER_IP} key "${TSIG_NAME}"; };
  file "/var/cache/bind/slave.db.${DOMAIN_PUBLIC}";
};
EOF

named-checkconf

# === Arranque Bind9 ===
if systemctl list-unit-files | grep -q '^named\.service'; then
  systemctl enable --now named.service || true
  systemctl restart named.service
else
  # No intentes enable si da problemas de alias; con restart basta para el parcial
  systemctl restart bind9 || systemctl restart bind9.service || true
fi

journalctl -u bind9 --no-pager -n 30 || true
