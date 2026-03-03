#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ===== Variables =====
DOMAIN_LOCAL="empresa.local"
DOMAIN_PUBLIC="juanjo.com"         
SUBDOMAIN_PUBLIC="parcial"              
MASTER_IP="192.168.56.10"
SLAVE_IP="192.168.56.11"
CLIENT_IP="192.168.56.12"
REV_ZONE="56.168.192.in-addr.arpa"

TSIG_NAME="empresa-transfer"
TSIG_FILE="/etc/bind/keys.${TSIG_NAME}.key"

# ===== Paquetes =====
apt-get update -y
apt-get install -y bind9 bind9utils dnsutils apache2
apt-get install -y openssh-server
systemctl enable --now ssh

# ===== Bind9: options seguras (no open resolver) =====
cat >/etc/bind/named.conf.options <<'EOF'
options {
  directory "/var/cache/bind";

  recursion no;
  allow-recursion { none; };

  listen-on { any; };
  allow-query { any; };

  dnssec-validation auto;
  auth-nxdomain no;
};
EOF

# ===== TSIG para AXFR seguro =====
if [ ! -f "${TSIG_FILE}" ]; then
  tsig-keygen -a hmac-sha256 "${TSIG_NAME}" > "${TSIG_FILE}"
  chown root:bind "${TSIG_FILE}"
  chmod 640 "${TSIG_FILE}"
fi

# ===== named.conf.local (zonas + notify + allow-transfer por TSIG) =====
cat >/etc/bind/named.conf.local <<EOF
include "${TSIG_FILE}";

server ${SLAVE_IP} {
  keys { "${TSIG_NAME}"; };
};

zone "${DOMAIN_LOCAL}" {
  type master;
  file "/etc/bind/db.${DOMAIN_LOCAL}";
  notify yes;
  allow-transfer { key "${TSIG_NAME}"; };
};

zone "${REV_ZONE}" {
  type master;
  file "/etc/bind/db.192.168.56";
  notify yes;
  allow-transfer { key "${TSIG_NAME}"; };
};

zone "${DOMAIN_PUBLIC}" {
  type master;
  file "/etc/bind/db.${DOMAIN_PUBLIC}";
  notify yes;
  allow-transfer { key "${TSIG_NAME}"; };
};
EOF

# ===== Zona directa empresa.local (A, AAAA, CNAME) =====
cat >/etc/bind/db.${DOMAIN_LOCAL} <<EOF
\$TTL 1h
@   IN  SOA maestro.${DOMAIN_LOCAL}. admin.${DOMAIN_LOCAL}. (
        2026030301 ; serial
        1h
        15m
        1w
        1h )

    IN  NS  maestro.${DOMAIN_LOCAL}.
    IN  NS  esclavo.${DOMAIN_LOCAL}.

maestro IN A     ${MASTER_IP}
esclavo IN A     ${SLAVE_IP}
cliente IN A     ${CLIENT_IP}

; AAAA de ejemplo (cumple requisito)
maestro IN AAAA  2001:db8::10

; CNAME
www     IN CNAME maestro
EOF

# ===== Zona inversa 192.168.56.0/24 =====
cat >/etc/bind/db.192.168.56 <<EOF
\$TTL 1h
@   IN  SOA maestro.${DOMAIN_LOCAL}. admin.${DOMAIN_LOCAL}. (
        2026030301 ; serial
        1h
        15m
        1w
        1h )

    IN NS maestro.${DOMAIN_LOCAL}.
    IN NS esclavo.${DOMAIN_LOCAL}.

10  IN PTR maestro.${DOMAIN_LOCAL}.
11  IN PTR esclavo.${DOMAIN_LOCAL}.
12  IN PTR cliente.${DOMAIN_LOCAL}.
EOF

# ===== Zona para parcial.juanjo.com =====
cat >/etc/bind/db.${DOMAIN_PUBLIC} <<EOF
\$TTL 1h
@   IN  SOA maestro.${DOMAIN_PUBLIC}. admin.${DOMAIN_PUBLIC}. (
        2026030301 ; serial
        1h
        15m
        1w
        1h )

    IN NS maestro.${DOMAIN_LOCAL}.
    IN NS esclavo.${DOMAIN_LOCAL}.

${SUBDOMAIN_PUBLIC} IN A ${MASTER_IP}
EOF

# ===== Validación y reinicio Bind =====
named-checkconf
named-checkzone "${DOMAIN_LOCAL}" "/etc/bind/db.${DOMAIN_LOCAL}"
named-checkzone "${REV_ZONE}" "/etc/bind/db.192.168.56"
named-checkzone "${DOMAIN_PUBLIC}" "/etc/bind/db.${DOMAIN_PUBLIC}"

# === Arranque Bind9 ===
if systemctl list-unit-files | grep -q '^named\.service'; then
  systemctl enable --now named.service || true
  systemctl restart named.service
else
  systemctl restart bind9 || systemctl restart bind9.service || true
fi

# ===== Apache: mod_deflate + exclusiones =====
a2enmod deflate headers >/dev/null
cat >/etc/apache2/conf-available/deflate-custom.conf <<'EOF'
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE \
    text/html text/plain text/xml text/css \
    application/javascript application/json application/xml \
    image/svg+xml

  SetEnvIfNoCase Request_URI "\.(?:gif|jpe?g|png|webp|ico|mp4|mov|avi|mkv|zip|gz|bz2|tgz|rar|7z)$" no-gzip dont-vary

  <IfModule mod_headers.c>
    Header append Vary Accept-Encoding
  </IfModule>
</IfModule>
EOF
a2enconf deflate-custom >/dev/null

# Página de prueba
cat >/var/www/html/index.html <<EOF
<!doctype html>
<html>
  <head>
    <meta charset="utf-8"/>
    <title>Parcial Servicios Telemáticos</title>
  </head>
  <body>
    <h1>Servidor Apache en maestro</h1>
    <p>Dominio: ${SUBDOMAIN_PUBLIC}.${DOMAIN_PUBLIC}</p>
    <p>Compresión gzip (mod_deflate) habilitada.</p>
  </body>
</html>
EOF

# VHost para parcial.juanjo.com
cat >/etc/apache2/sites-available/${SUBDOMAIN_PUBLIC}.${DOMAIN_PUBLIC}.conf <<EOF
<VirtualHost *:80>
  ServerName ${SUBDOMAIN_PUBLIC}.${DOMAIN_PUBLIC}
  DocumentRoot /var/www/html

  ErrorLog \${APACHE_LOG_DIR}/${SUBDOMAIN_PUBLIC}_error.log
  CustomLog \${APACHE_LOG_DIR}/${SUBDOMAIN_PUBLIC}_access.log combined
</VirtualHost>
EOF
a2ensite ${SUBDOMAIN_PUBLIC}.${DOMAIN_PUBLIC}.conf >/dev/null

systemctl enable --now apache2
systemctl reload apache2

# Mostrar TSIG por consola (útil para copiar/verificar si lo necesitas)
echo "=== TSIG KEY (maestro) ==="
cat "${TSIG_FILE}"
