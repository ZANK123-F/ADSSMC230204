@echo off
REM Ejecutar en SRV-DC01 como Administrador
REM Requiere C:\Temp\web.csr (copiado desde Ubuntu /tmp/web.csr)

if not exist C:\Temp\web.csr (
  echo Falta C:\Temp\web.csr
  echo Copia el CSR desde Ubuntu: cat /tmp/web.csr
  exit /b 1
)

certreq -submit -attrib "CertificateTemplate:WebServer" C:\Temp\web.csr C:\Temp\web.cer
if errorlevel 1 (
  echo Fallo certreq. Revisa que la plantilla WebServer este publicada en la CA.
  exit /b 1
)

certutil -ca.cert C:\Temp\CORP-CA.cer
certutil -dump C:\Temp\web.cer
echo.
echo Listo:
echo   C:\Temp\web.cer
echo   C:\Temp\CORP-CA.cer
echo Copia ambos a /tmp/ en Ubuntu y corre:
echo   sudo bash 02-ubuntu-csr-https-ftps.sh CARNET --install-certs
