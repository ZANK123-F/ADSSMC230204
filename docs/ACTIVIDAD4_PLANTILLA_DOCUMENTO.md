# UNIVERSIDAD DON BOSCO
## Diseño de Sistemas de Seguridad / Redes de Datos
### Actividad 4: Validación — Comercial El Triunfo S.A. de C.V.

**Integrantes:**  
- Guevara Alfaro, René Francisco  
- Marroquín Carmona, Franly Azael  
*(agregar el resto si aplica)*

**Docente:** Ing. Cesar Guzman  
**Fecha:** noviembre 2026

---

## 1. Introducción

El presente documento describe la implementación y validación de mecanismos de seguridad sobre la infraestructura tecnológica de Comercial El Triunfo S.A. de C.V., desarrollada previamente en la Actividad 3. Se implementó una Autoridad Certificadora (AD CS) en Windows Server, la publicación del sitio institucional mediante HTTPS y un servicio FTPS para la administración segura de archivos en el servidor web Ubuntu.

## 2. Descripción de las configuraciones realizadas

### 2.1 Ambiente

| Componente | Detalle |
|------------|---------|
| Hipervisor | Oracle VM VirtualBox — Red NAT `TRIUNFO-LAB` (`10.10.10.0/24`) |
| SRV-DC01 | Windows Server 2022 — `10.10.10.10` — AD DS, DNS, AD CS |
| SRV-WEB01 | Ubuntu 24.04 — `10.10.10.20` — Apache HTTPS, vsftpd FTPS |
| Dominio | `corp.comercialeltriunfo.com` |
| Sitio | `https://web.corp.comercialeltriunfo.com` |

### 2.2 Autoridad Certificadora (AD CS)

- Instalación del rol Active Directory Certificate Services.
- Configuración de Enterprise Root CA (`CORP-CA`), RSA 2048, SHA256.
- Publicación de la plantilla **Web Server**.
- Emisión del certificado para `web.corp.comercialeltriunfo.com` a partir de CSR generado en Ubuntu.

### 2.3 HTTPS en el servidor web

- Generación de clave privada y CSR con OpenSSL en Ubuntu.
- Instalación del certificado emitido por CORP-CA y cadena de confianza.
- Habilitación de `mod_ssl` y VirtualHost en puerto 443.
- Validación de acceso HTTPS desde SRV-DC01.

### 2.4 FTPS

- Instalación y configuración de **vsftpd** con TLS obligatorio.
- Reutilización del certificado digital de la CA corporativa.
- Usuario FTPS: carnet del integrante `__________`.
- Conexión y transferencia de archivos con FileZilla Client (FTP explícito sobre TLS) desde Windows Server.

## 3. Evidencias de la Autoridad Certificadora

*(Pegar capturas)*

- Figura 1. Instalación del rol AD CS  
- Figura 2. Servicio CertSvc / `certutil -CAInfo`  
- Figura 3. Plantilla Web Server publicada  
- Figura 4. Emisión del certificado (`certreq` / Issued Certificates)

## 4. Evidencias de la configuración de HTTPS

- Figura 5. CSR / archivos en `/etc/ssl/comercialeltriunfo/`  
- Figura 6. VirtualHost SSL Apache / `apache2ctl configtest`  
- Figura 7. Navegador: `https://web.corp.comercialeltriunfo.com`  
- Figura 8. Detalle del certificado digital en el navegador (sujeto y emisor CORP-CA)

## 5. Evidencias de la implementación de FTPS

- Figura 9. Estado del servicio vsftpd y parámetros SSL  
- Figura 10. FileZilla conectado por FTPS con usuario carnet  
- Figura 11. Transferencia de archivo Windows → Ubuntu  
- Figura 12. Verificación del archivo en el servidor Ubuntu

## 6. Evidencias de las pruebas realizadas

| Prueba | Resultado | Evidencia |
|--------|-----------|-----------|
| CA operativa (CertSvc / certutil) | OK / FAIL | Fig. |
| Emisión de certificado Web Server | OK / FAIL | Fig. |
| HTTPS desde SRV-DC01 | OK / FAIL | Fig. |
| Validación del certificado en navegador | OK / FAIL | Fig. |
| Conexión FTPS FileZilla (usuario carnet) | OK / FAIL | Fig. |
| Transferencia de archivos por FTPS | OK / FAIL | Fig. |
| Infraestructura previa (AD, DNS, web) | OK / FAIL | Fig. |

## 7. Conclusiones

Se implementó una Autoridad Certificadora empresarial sobre Active Directory Certificate Services, permitiendo emitir certificados digitales para proteger los servicios de Comercial El Triunfo. El sitio institucional quedó disponible mediante HTTPS y la administración de archivos del servidor web se realiza de forma cifrada a través de FTPS, cumpliendo los requerimientos de seguridad solicitados por la Gerencia previo a la entrada en operación.
