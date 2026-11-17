# Ejecutar en SRV-DC01 como Administrador
# Instala y configura Enterprise Root CA CORP-CA + publica plantilla WebServer

$ErrorActionPreference = "Stop"

Write-Host "==> Instalando rol AD CS..." -ForegroundColor Cyan
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

Write-Host "==> Configurando Enterprise Root CA (CORP-CA)..." -ForegroundColor Cyan
Install-AdcsCertificationAuthority `
  -CAType EnterpriseRootCA `
  -CACommonName "CORP-CA" `
  -KeyLength 2048 `
  -HashAlgorithmName SHA256 `
  -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
  -ValidityPeriod Years `
  -ValidityPeriodUnits 5 `
  -Force

Write-Host "==> Publicando plantilla WebServer..." -ForegroundColor Cyan
try {
  Add-CATemplate -Name "WebServer" -ErrorAction Stop
} catch {
  Write-Host "Aviso: publica Web Server manualmente desde certsrv.msc si falla Add-CATemplate." -ForegroundColor Yellow
}

Write-Host "==> Estado del servicio:" -ForegroundColor Cyan
Get-Service CertSvc | Format-Table Name, Status, StartType
certutil -ping
certutil -CAInfo

New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null
certutil -ca.cert C:\Temp\CORP-CA.cer
Write-Host "CA root exportada a C:\Temp\CORP-CA.cer" -ForegroundColor Green
Write-Host "Listo. Siguiente: emitir cert con certreq usando el CSR de Ubuntu." -ForegroundColor Green
