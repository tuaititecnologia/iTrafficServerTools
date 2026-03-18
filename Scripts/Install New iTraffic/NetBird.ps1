# Instala la última versión de NetBird Client y lo registra con una setup key ingresada por consola.

$ManagementUrl = "https://netbird.tuaiti.com.ar"
$tmpMsiPath    = Join-Path $env:TEMP "netbird_installer_windows_amd64.msi"
$tmpLogPath    = Join-Path $env:TEMP "netbird-install.log"
$netbirdExe    = "C:\Program Files\NetBird\netbird.exe"

Write-Host ""
Write-Host "=========================================" -ForegroundColor DarkGray
Write-Host "         INSTALACIÓN DE NETBIRD          " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor DarkGray

# Obtener setup key
do {
    $setup_key = Read-Host "Ingresá la Setup Key de NetBird"
} while ([string]::IsNullOrWhiteSpace($setup_key))

# Obtener URL del último release
Write-Host "Obteniendo URL de la última versión de NetBird..." -ForegroundColor Cyan
$release  = Invoke-RestMethod -Uri "https://api.github.com/repos/netbirdio/netbird/releases/latest"
$msiAsset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "amd64" -and $_.name -match "\.msi$" } | Select-Object -First 1

if (-not $msiAsset) {
    $msiAsset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "\.msi$" } | Select-Object -First 1
}

if (-not $msiAsset) {
    Write-Host "No se encontró un instalador MSI de NetBird para Windows. Abortando." -ForegroundColor Red
    return
}

$downloadUrl = [string]$msiAsset.browser_download_url

if (Test-Path $tmpMsiPath) {
    Write-Host "MSI ya descargado, reutilizando: $tmpMsiPath" -ForegroundColor DarkGray
} else {
    Write-Host "Descargando MSI desde: $downloadUrl" -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpMsiPath -UseBasicParsing

    if (-not (Test-Path $tmpMsiPath)) {
        Write-Host "La descarga del MSI no se completó correctamente. Abortando." -ForegroundColor Red
        return
    }
}

# Instalación silenciosa
Write-Host "Instalando NetBird en modo silencioso..." -ForegroundColor Cyan
$msiArgs = @(
    "/i", "`"$tmpMsiPath`"",
    "/qn",
    "/norestart",
    "/L*v", "`"$tmpLogPath`""
)
$install = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow

Remove-Item $tmpMsiPath -Force -ErrorAction SilentlyContinue

if ($install.ExitCode -ne 0) {
    Write-Host "Falló la instalación MSI. ExitCode=$($install.ExitCode). Revisar log: $tmpLogPath" -ForegroundColor Red
    return
}

if (-not (Test-Path $netbirdExe)) {
    Write-Host "NetBird no quedó instalado en la ruta esperada: $netbirdExe" -ForegroundColor Red
    return
}

# Registrar con la setup key
Write-Host "Registrando cliente en NetBird..." -ForegroundColor Cyan
& $netbirdExe up --management-url $ManagementUrl --setup-key $setup_key

if ($LASTEXITCODE -ne 0) {
    Write-Host "NetBird no pudo registrarse. ExitCode=$LASTEXITCODE" -ForegroundColor Red
    return
}

Write-Host "NetBird instalado y registrado correctamente." -ForegroundColor Green
