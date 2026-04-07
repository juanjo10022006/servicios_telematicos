#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  vsftpd \
  openssh-server \
  openssl \
  net-tools \
  iputils-ping \
  traceroute \
  curl \
  wget \
  tcpdump

systemctl enable ssh
systemctl start ssh

systemctl enable vsftpd
systemctl start vsftpd

# Usuario para FTPS/SFTP
if ! id ftpuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash ftpuser
fi

echo 'ftpuser:123456' | chpasswd

mkdir -p /home/ftpuser
echo 'Archivo inicial de prueba FTPS/SFTP' > /home/ftpuser/prueba.txt
chown -R ftpuser:ftpuser /home/ftpuser


sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
systemctl restart ssh


mkdir -p /etc/ssl/vsftpd
cd /etc/ssl/vsftpd

if [ ! -f ca.key ]; then
  openssl genrsa -out ca.key 2048
fi

if [ ! -f ca.crt ]; then
  openssl req -new -x509 -key ca.key -out ca.crt -days 365 \
    -subj "/C=CO/ST=Valle/L=Cali/O=UAO/CN=CA-FTPS"
fi

if [ ! -f server.key ]; then
  openssl genrsa -out server.key 2048
fi

if [ ! -f server.csr ]; then
  openssl req -new -key server.key -out server.csr \
    -subj "/C=CO/ST=Valle/L=Cali/O=UAO/CN=192.168.50.3"
fi

if [ ! -f server.crt ]; then
  openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days 365
fi

chmod 600 /etc/ssl/vsftpd/server.key


cat > /etc/vsftpd.conf <<'EOF'
listen=YES
listen_ipv6=NO

anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022

dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

chroot_local_user=YES
allow_writeable_chroot=YES

ssl_enable=YES
allow_anon_ssl=NO
force_local_logins_ssl=YES
force_local_data_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO

rsa_cert_file=/etc/ssl/vsftpd/server.crt
rsa_private_key_file=/etc/ssl/vsftpd/server.key

pasv_enable=YES
pasv_min_port=50000
pasv_max_port=50010
pasv_address=192.168.50.3

seccomp_sandbox=NO
EOF

systemctl restart vsftpd

echo "Provision servidor2 completado."
