# Instala NetBird Client (ultima version) y lo registra con setup key.
# Script standalone para ejecutar fuera del instalador principal.

[CmdletBinding()]
param(
    [string]$SetupKey = "A1BE744B-02BA-4D0F-A7A9-437B7385CA54",
    [string]$ManagementUrl = "https://netbird.tuaiti.com.ar",
    [switch]$SkipRegistration
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LatestNetBirdMsiUrl {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/netbirdio/netbird/releases/latest"
    $msiAsset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "amd64" -and $_.name -match "\.msi$" } | Select-Object -First 1

    if (-not $msiAsset) {
        $msiAsset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "\.msi$" } | Select-Object -First 1
    }

    if (-not $msiAsset) {
        throw "No se encontro un instalador MSI de NetBird para Windows en el ultimo release."
    }

    return [string]$msiAsset.browser_download_url
}

if (-not (Test-IsAdmin)) {
    throw "Este script requiere PowerShell con privilegios de administrador."
}

if (-not $SkipRegistration -and [string]::IsNullOrWhiteSpace($SetupKey)) {
    throw "Debes definir una SetupKey valida o usar -SkipRegistration."
}

$tmpMsiPath = Join-Path $env:TEMP "netbird_installer_windows_amd64.msi"
$tmpLogPath = Join-Path $env:TEMP "netbird-install.log"
$netbirdExe = "C:\Program Files\NetBird\netbird.exe"

try {
    Write-Host "Obteniendo URL de la ultima version de NetBird..." -ForegroundColor Cyan
    $downloadUrl = Get-LatestNetBirdMsiUrl
    Write-Host "Descargando MSI desde: $downloadUrl" -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpMsiPath -UseBasicParsing

    if (-not (Test-Path $tmpMsiPath)) {
        throw "La descarga del MSI no se completo correctamente."
    }

    Write-Host "Instalando NetBird en modo silencioso..." -ForegroundColor Cyan
    $msiArgs = @(
        "/i", "`"$tmpMsiPath`"",
        "/qn",
        "/norestart",
        "/L*v", "`"$tmpLogPath`""
    )

    # Si no queres registrar durante MSI, usa -SkipRegistration.
    if (-not $SkipRegistration) {
        $msiArgs += "SETUP_KEY=$SetupKey"
        if (-not [string]::IsNullOrWhiteSpace($ManagementUrl)) {
            $msiArgs += "MANAGEMENT_URL=$ManagementUrl"
        }
    }

    $install = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
    if ($install.ExitCode -ne 0) {
        throw "Fallo la instalacion MSI. ExitCode=$($install.ExitCode). Revisar log: $tmpLogPath"
    }

    if (-not (Test-Path $netbirdExe)) {
        throw "NetBird no quedo instalado en la ruta esperada: $netbirdExe"
    }

    $service = Get-Service -Name "*NetBird*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($service -and $service.Status -ne "Running") {
        Start-Service -Name $service.Name
    }

    if (-not $SkipRegistration) {
        Write-Host "Registrando cliente en NetBird..." -ForegroundColor Cyan
        $connectArgs = @("up", "--setup-key", $SetupKey)
        if (-not [string]::IsNullOrWhiteSpace($ManagementUrl)) {
            $connectArgs += @("--management-url", $ManagementUrl)
        }

        & $netbirdExe @connectArgs
        if ($LASTEXITCODE -ne 0) {
            throw "NetBird no pudo registrarse con la setup key. ExitCode=$LASTEXITCODE"
        }
    }

    Write-Host "NetBird instalado correctamente." -ForegroundColor Green
}
finally {
    if (Test-Path $tmpMsiPath) {
        Remove-Item $tmpMsiPath -Force -ErrorAction SilentlyContinue
    }
}
