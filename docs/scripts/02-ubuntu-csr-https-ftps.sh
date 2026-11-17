#!/usr/bin/env bash
# Ejecutar en srv-web01 (Ubuntu) con sudo
# Uso: sudo bash 02-ubuntu-csr-https-ftps.sh CARNET
# 1) Genera CSR/clave
# 2) Tras emitir el .cer en Windows y copiar web.cer + CORP-CA.cer a /tmp/,
#    re-ejecutar con: sudo bash 02-ubuntu-csr-https-ftps.sh CARNET --install-certs
set -euo pipefail

CARNET="${1:-}"
MODE="${2:-}"

if [[ -z "$CARNET" ]]; then
  echo "Uso: sudo bash $0 <CARNET> [--install-certs]"
  exit 1
fi

SSL_DIR=/etc/ssl/comercialeltriunfo
mkdir -p "$SSL_DIR"

if [[ "$MODE" != "--install-certs" ]]; then
  echo "==> Generando clave y CSR para web.corp.comercialeltriunfo.com"
  openssl req -new -newkey rsa:2048 -nodes \
    -keyout "$SSL_DIR/web.key" \
    -out /tmp/web.csr \
    -subj "/C=SV/ST=San Salvador/L=San Salvador/O=Comercial El Triunfo S.A. de C.V./OU=Informatica/CN=web.corp.comercialeltriunfo.com"
  chmod 600 "$SSL_DIR/web.key"
  echo
  echo "CSR listo en /tmp/web.csr — copialo a C:\\Temp\\web.csr en SRV-DC01 y ejecutá:"
  echo "  certreq -submit -attrib \"CertificateTemplate:WebServer\" C:\\Temp\\web.csr C:\\Temp\\web.cer"
  echo "Luego copiá web.cer y CORP-CA.cer a /tmp/ en Ubuntu y corré:"
  echo "  sudo bash $0 $CARNET --install-certs"
  cat /tmp/web.csr
  exit 0
fi

echo "==> Instalando certificados emitidos por la CA"
cp /tmp/web.cer "$SSL_DIR/web.crt"
cp /tmp/CORP-CA.cer "$SSL_DIR/CORP-CA.crt"
cat "$SSL_DIR/web.crt" "$SSL_DIR/CORP-CA.crt" > "$SSL_DIR/web-chain.crt"
chmod 644 "$SSL_DIR/web.crt" "$SSL_DIR/CORP-CA.crt" "$SSL_DIR/web-chain.crt"

echo "==> Configurando Apache HTTPS"
a2enmod ssl headers
cat > /etc/apache2/sites-available/triunfo-ssl.conf <<'EOF'
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName web.corp.comercialeltriunfo.com
    ServerAdmin webadmin@corp.comercialeltriunfo.com
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile      /etc/ssl/comercialeltriunfo/web.crt
    SSLCertificateKeyFile   /etc/ssl/comercialeltriunfo/web.key
    SSLCertificateChainFile /etc/ssl/comercialeltriunfo/web-chain.crt

    ErrorLog ${APACHE_LOG_DIR}/error-ssl.log
    CustomLog ${APACHE_LOG_DIR}/access-ssl.log combined
</VirtualHost>
</IfModule>
EOF
a2ensite triunfo-ssl.conf
apache2ctl configtest
systemctl reload apache2

echo "==> Instalando y configurando vsftpd (FTPS)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y vsftpd

if ! id "$CARNET" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "FTPS $CARNET" "$CARNET"
  echo "Usuario $CARNET creado. Asigná password con: passwd $CARNET"
fi
usermod -aG www-data "$CARNET" || true
chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html

cp /etc/vsftpd.conf /etc/vsftpd.conf.bak.$(date +%s)
cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
local_root=/var/www/html
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
ssl_enable=YES
rsa_cert_file=/etc/ssl/comercialeltriunfo/web.crt
rsa_private_key_file=/etc/ssl/comercialeltriunfo/web.key
force_local_logins_ssl=YES
force_local_data_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
pasv_address=10.10.10.20
EOF
echo "$CARNET" > /etc/vsftpd.userlist

ufw allow 443/tcp || true
ufw allow 21/tcp || true
ufw allow 40000:50000/tcp || true
systemctl restart vsftpd
systemctl enable vsftpd

echo
echo "OK. Probá:"
echo "  curl -vkI https://web.corp.comercialeltriunfo.com --resolve web.corp.comercialeltriunfo.com:443:10.10.10.20"
echo "  FileZilla FTPS Explicit → 10.10.10.20:21 usuario $CARNET"
systemctl status apache2 --no-pager | head -n 15
systemctl status vsftpd --no-pager | head -n 15
