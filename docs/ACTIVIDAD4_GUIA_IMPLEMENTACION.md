# Actividad 4 — Guía de implementación (CA + HTTPS + FTPS)

Infraestructura base (Actividad 3):

| Servidor   | Hostname   | IP           | Rol                          |
|------------|------------|--------------|------------------------------|
| Windows    | SRV-DC01   | 10.10.10.10  | AD DS, DNS, **AD CS (nuevo)** |
| Ubuntu     | srv-web01  | 10.10.10.20  | Apache, **HTTPS + FTPS**     |
| Dominio    | corp.comercialeltriunfo.com | | |
| Sitio      | web.corp.comercialeltriunfo.com → 10.10.10.20 | | |

Red VirtualBox: **Red NAT `TRIUNFO-LAB`** (`10.10.10.0/24`).

> Sustituí `CARNET` por el carnet real de un integrante (usuario FTPS).

---

## FASE 0 — Checklist previo (ya deberían estar OK)

En `SRV-DC01`:

```cmd
ping 10.10.10.20
nslookup web.corp.comercialeltriunfo.com 127.0.0.1
```

En `srv-web01`:

```bash
systemctl status apache2 --no-pager
curl -I http://10.10.10.20
```

**Captura:** conectividad + sitio HTTP actual (antes de HTTPS).

---

## FASE 1 — Autoridad Certificadora en Windows (AD CS)

### 1.1 Instalar rol AD CS

Abrí **PowerShell como Administrador** en `SRV-DC01`:

```powershell
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
```

**Captura:** instalación del rol / Administrador del servidor con AD CS.

### 1.2 Configurar Enterprise Root CA

```powershell
Install-AdcsCertificationAuthority `
  -CAType EnterpriseRootCA `
  -CACommonName "CORP-CA" `
  -KeyLength 2048 `
  -HashAlgorithmName SHA256 `
  -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
  -ValidityPeriod Years `
  -ValidityPeriodUnits 5 `
  -Force
```

Si pregunta confirmación, aceptá.

Verificación:

```powershell
Get-Service CertSvc
certutil -ping
certutil -CAInfo
```

**Captura:** `CertSvc` Running + salida de `certutil -CAInfo` (evidencia de CA operativa).

### 1.3 Publicar plantilla Web Server

1. `Win + R` → `certtmpl.msc` → Enter  
2. Buscá **Web Server** → clic derecho → **Propiedades** → **Seguridad**  
   - Agregá **Domain Admins** (o Authenticated Users) con **Enroll** y **Read**  
3. `Win + R` → `certsrv.msc` → Enter  
4. Expandí tu CA → clic derecho **Certificate Templates** / **Plantillas de certificado**  
5. **Nuevo → Certificate Template to Issue** → elegí **Web Server** → OK  

PowerShell alternativo para publicar la plantilla:

```powershell
Add-CATemplate -Name "WebServer"
```

**Captura:** plantilla Web Server publicada en la CA.

---

## FASE 2 — Emitir certificado para el sitio web

Flujo recomendado: **CSR en Ubuntu → emitir en la CA de Windows → volver a Ubuntu**.

### 2.1 Generar clave + CSR en Ubuntu

En `srv-web01`:

```bash
sudo mkdir -p /etc/ssl/comercialeltriunfo
sudo openssl req -new -newkey rsa:2048 -nodes \
  -keyout /etc/ssl/comercialeltriunfo/web.key \
  -out /tmp/web.csr \
  -subj "/C=SV/ST=San Salvador/L=San Salvador/O=Comercial El Triunfo S.A. de C.V./OU=Informatica/CN=web.corp.comercialeltriunfo.com"

sudo chmod 600 /etc/ssl/comercialeltriunfo/web.key
ls -l /tmp/web.csr /etc/ssl/comercialeltriunfo/web.key
```

**Captura:** generación del CSR.

### 2.2 Copiar el CSR a Windows

Opciones fáciles:

- Shared folder de VirtualBox, o  
- Desde Windows (si tenés OpenSSH/smb), o  
- Pegar contenido: en Ubuntu `cat /tmp/web.csr` y guardar en `C:\Temp\web.csr` en el DC.

En Ubuntu:

```bash
cat /tmp/web.csr
```

En `SRV-DC01`, creá `C:\Temp\web.csr` con ese contenido (Bloc de notas, UTF-8 sin rarezas).

### 2.3 Emitir el certificado en la CA

PowerShell / CMD admin en `SRV-DC01`:

```cmd
mkdir C:\Temp 2>nul
certreq -submit -attrib "CertificateTemplate:WebServer" C:\Temp\web.csr C:\Temp\web.cer
```

Si sale diálogo de CA, elegí **CORP-CA**.

Si falla por plantilla, emití desde GUI:

1. `certsrv.msc` → Pending/Issued  
2. O: Administrador de certificados → solicitar con CSR

Verificación:

```cmd
certutil -dump C:\Temp\web.cer
```

**Captura:** `certreq` exitoso + certificado emitido en la CA (Issued Certificates).

### 2.4 Exportar también el certificado raíz de la CA

```powershell
certutil -ca.cert C:\Temp\CORP-CA.cer
```

### 2.5 Llevar `web.cer` y `CORP-CA.cer` a Ubuntu

Copiá ambos a Ubuntu, por ejemplo a `/tmp/`, luego:

```bash
sudo cp /tmp/web.cer /etc/ssl/comercialeltriunfo/web.crt
sudo cp /tmp/CORP-CA.cer /etc/ssl/comercialeltriunfo/CORP-CA.crt
sudo chmod 644 /etc/ssl/comercialeltriunfo/web.crt /etc/ssl/comercialeltriunfo/CORP-CA.crt
```

Crear cadena (cert + CA) para Apache:

```bash
sudo bash -c 'cat /etc/ssl/comercialeltriunfo/web.crt /etc/ssl/comercialeltriunfo/CORP-CA.crt > /etc/ssl/comercialeltriunfo/web-chain.crt'
```

**Captura:** archivos en `/etc/ssl/comercialeltriunfo/`.

---

## FASE 3 — HTTPS en Apache (Ubuntu)

### 3.1 Habilitar SSL

```bash
sudo a2enmod ssl headers
sudo a2ensite default-ssl
```

### 3.2 Configurar VirtualHost HTTPS

Editá (o creá) el sitio SSL. Opción simple: editar `default-ssl`:

```bash
sudo nano /etc/apache2/sites-available/default-ssl.conf
```

Asegurate de tener algo así (ajustá DocumentRoot si tu sitio está en otra ruta):

```apache
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
```

Si usás un sitio propio (no `default-ssl`), crealo en `sites-available` y habilitalo con `a2ensite`.

### 3.3 Probar y recargar

```bash
sudo apache2ctl configtest
sudo systemctl reload apache2
sudo ss -tlnp | grep -E ':443|:80'
curl -vkI https://127.0.0.1/ --resolve web.corp.comercialeltriunfo.com:443:127.0.0.1
```

Abrí firewall si aplica:

```bash
sudo ufw allow 443/tcp
sudo ufw status
```

**Captura:** `apache2ctl configtest` Syntax OK + listening 443 + `curl -vkI` mostrando el certificado.

### 3.4 Probar desde Windows (obligatorio en defensa)

En el navegador de `SRV-DC01`:

```
https://web.corp.comercialeltriunfo.com
```

En el candado del navegador → certificado:

- Emitido para: `web.corp.comercialeltriunfo.com`
- Emitido por: `CORP-CA`

Si el navegador no confía (raro en el DC con Enterprise CA, a veces pasa):

```powershell
Import-Certificate -FilePath C:\Temp\CORP-CA.cer -CertStoreLocation Cert:\LocalMachine\Root
```

**Capturas obligatorias:**
1. Sitio abriendo por **HTTPS**
2. Detalle del certificado en el navegador (emisor CORP-CA)

---

## FASE 4 — FTPS en Ubuntu (vsftpd + certificado)

### 4.1 Instalar vsftpd

```bash
sudo apt update
sudo apt install -y vsftpd
```

### 4.2 Crear usuario = carnet del integrante

```bash
sudo adduser CARNET
# password: elegí una (anotala para FileZilla)
```

Dar acceso a los archivos del sitio (administración web):

```bash
sudo usermod -aG www-data CARNET
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 775 /var/www/html
sudo mkdir -p /home/CARNET/ftp-files
sudo chown CARNET:CARNET /home/CARNET/ftp-files
```

> Para la demo de transferencia, podés subir a `/home/CARNET` o a `/var/www/html`.  
> Si querés que FileZilla caiga directo al webroot, usá `local_root` (abajo).

### 4.3 Configurar vsftpd con FTPS

Respaldo y config:

```bash
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
sudo nano /etc/vsftpd.conf
```

Dejá / agregá estas líneas clave (el resto puede quedar; evitá duplicados contradictorios):

```conf
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
# Si querés administrar el sitio web desde FTPS, descomentá:
# local_root=/var/www/html

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
```

Usuarios permitidos (recomendado):

```bash
echo "CARNET" | sudo tee /etc/vsftpd.userlist
```

Y en `vsftpd.conf`:

```conf
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
```

### 4.4 Firewall + reinicio

```bash
sudo ufw allow 21/tcp
sudo ufw allow 40000:50000/tcp
sudo systemctl restart vsftpd
sudo systemctl status vsftpd --no-pager
sudo ss -tlnp | grep -E ':21|vsftpd'
```

**Captura:** `vsftpd` active + config SSL habilitada.

### 4.5 FileZilla desde Windows Server

1. Instalá **FileZilla Client** en `SRV-DC01` (si no está).
2. Archivo → Administrador de sitios → Nuevo sitio:
   - Protocolo: **FTP - File Transfer Protocol**
   - Cifrado: **Requerir FTP explícito sobre TLS** (FTPS Explicit)
   - Host: `10.10.10.20` o `web.corp.comercialeltriunfo.com`
   - Puerto: `21`
   - Tipo de acceso: Normal
   - Usuario: `CARNET`
   - Contraseña: la que definiste
3. Conectar → si avisa del certificado, **aceptar** (es el de CORP-CA).
4. Subí un archivo de prueba (ej. `prueba-ftps.txt`) desde Windows hacia Ubuntu.
5. Verificá en Ubuntu:

```bash
ls -l /home/CARNET/
# o /var/www/html si usaste local_root
```

**Capturas obligatorias:**
1. FileZilla conectado por FTPS (candado / TLS)
2. Transferencia exitosa Windows → Ubuntu
3. Archivo visible en el servidor Ubuntu

---

## FASE 5 — Guion de defensa (Presentación Técnica)

Demostrar en este orden:

1. **CA viva** — `certsrv.msc` + `Get-Service CertSvc`
2. **Certificados emitidos** — Issued Certificates (`web.corp...`)
3. **HTTPS** — Edge/Chrome: `https://web.corp.comercialeltriunfo.com`
4. **Validar cert en navegador** — emisor CORP-CA, sujeto web...
5. **FTPS FileZilla** — usuario carnet
6. **Transferencia de archivo** Windows → Ubuntu
7. **Infra completa** — ping, DNS, AD OUs (rápido)

---

## FASE 6 — Contenido mínimo del PDF

1. Introducción  
2. Descripción de las configuraciones realizadas (AD CS, HTTPS, FTPS)  
3. Evidencias Autoridad Certificadora  
4. Evidencias HTTPS  
5. Evidencias FTPS  
6. Evidencias de pruebas  
7. Conclusiones  

Usá lenguaje técnico. Entrega en **PDF**.

---

## Problemas frecuentes

| Síntoma | Qué revisar |
|---------|-------------|
| `certreq` no encuentra plantilla | Publicar **Web Server** en la CA |
| Apache falla al iniciar SSL | Rutas del `.crt`/`.key`, `apache2ctl configtest` |
| HTTPS con candado roto en DC | Importar `CORP-CA.cer` a Trusted Root |
| FileZilla timeout tras login | Puertos pasivos 40000-50000 + `pasv_address=10.10.10.20` |
| FileZilla “plain FTP” | Elegir **FTP explícito sobre TLS** |
| `Nombre: No seleccionado` en VB | Administrador de red → Red NAT `TRIUNFO-LAB` |

---

## Orden de capturas sugerido (para el PDF)

1. AD CS instalado / CORP-CA  
2. `certutil -CAInfo`  
3. Plantilla Web Server publicada  
4. CSR + emisión `certreq`  
5. Certificado en Issued Certificates  
6. Apache SSL config + `configtest`  
7. Navegador HTTPS + detalle del certificado  
8. vsftpd status + conf SSL  
9. FileZilla FTPS conectado (usuario carnet)  
10. Upload exitoso + `ls` en Ubuntu  
