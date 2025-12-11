# Script para configurar exclusiones de Windows Defender
# Evita que el escaneo programado se quede colgado en servidores con IIS y SQL Server
# Basado en las mejores prácticas de Microsoft
# Requiere permisos de administrador

# Verificar que se ejecuta como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Este script requiere permisos de administrador" -ForegroundColor Red
    Write-Host "Ejecuta PowerShell como administrador y vuelve a intentar" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Configurando exclusiones de Windows Defender ===" -ForegroundColor Cyan
Write-Host "Basado en las mejores prácticas de Microsoft" -ForegroundColor Gray
Write-Host ""

# ============================================
# EXCLUSIONES PARA SQL SERVER
# ============================================

Write-Host "Configurando exclusiones para SQL Server..." -ForegroundColor Yellow

# Binarios de SQL Server (todas las versiones)
$sqlPaths = @(
    "C:\Program Files\Microsoft SQL Server",
    "C:\Program Files (x86)\Microsoft SQL Server"
)

foreach ($path in $sqlPaths) {
    if (Test-Path $path) {
        try {
            Add-MpPreference -ExclusionPath $path -ErrorAction Stop
            Write-Host "  [OK] Excluido: $path" -ForegroundColor Green
        } catch {
            Write-Host "  [ADVERTENCIA] No se pudo excluir $path : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Extensiones de archivos de SQL Server
# IMPORTANTE: Estas exclusiones son GLOBALES y cubren archivos en CUALQUIER ubicación del sistema
# Esto incluye ubicaciones personalizadas como E:\SQLDATA, D:\SQLData, etc.
$sqlExtensions = @(".mdf", ".ndf", ".ldf", ".bak", ".trn", ".trc")
foreach ($ext in $sqlExtensions) {
    try {
        Add-MpPreference -ExclusionExtension $ext -ErrorAction Stop
        Write-Host "  [OK] Excluida extensión: $ext (global - cubre todas las ubicaciones)" -ForegroundColor Green
    } catch {
        Write-Host "  [ADVERTENCIA] No se pudo excluir extensión $ext : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Procesos de SQL Server (según recomendaciones de Microsoft)
$sqlProcesses = @(
    "sqlservr.exe",              # Motor principal de SQL Server
    "sqlagent.exe",              # SQL Server Agent
    "fdhost.exe",                # Full-Text Filter Daemon Host
    "msmdsrv.exe",               # Analysis Services (si está instalado)
    "ReportingServicesService.exe"  # Reporting Services (si está instalado)
)

foreach ($process in $sqlProcesses) {
    try {
        Add-MpPreference -ExclusionProcess $process -ErrorAction Stop
        Write-Host "  [OK] Excluido proceso: $process" -ForegroundColor Green
    } catch {
        Write-Host "  [ADVERTENCIA] No se pudo excluir proceso $process : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""

# ============================================
# EXCLUSIONES PARA IIS
# ============================================

Write-Host "Configurando exclusiones para IIS..." -ForegroundColor Yellow

# Directorio de sitios web (incluye logs automáticamente)
if (Test-Path "C:\inetpub") {
    try {
        Add-MpPreference -ExclusionPath "C:\inetpub" -ErrorAction Stop
        Write-Host "  [OK] Excluido: C:\inetpub" -ForegroundColor Green
    } catch {
        Write-Host "  [ADVERTENCIA] No se pudo excluir C:\inetpub : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Directorios de configuración y binarios de IIS (según recomendaciones de Microsoft)
$iisSystemPaths = @(
    "$env:SystemRoot\System32\inetsrv",
    "$env:SystemRoot\SysWOW64\inetsrv"
)

foreach ($path in $iisSystemPaths) {
    if (Test-Path $path) {
        try {
            Add-MpPreference -ExclusionPath $path -ErrorAction Stop
            Write-Host "  [OK] Excluido: $path" -ForegroundColor Green
        } catch {
            Write-Host "  [ADVERTENCIA] No se pudo excluir $path : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Archivos ASP.NET temporales
$netFrameworkPaths = @(
    "C:\Windows\Microsoft.NET\Framework",
    "C:\Windows\Microsoft.NET\Framework64"
)

foreach ($path in $netFrameworkPaths) {
    if (Test-Path $path) {
        try {
            Add-MpPreference -ExclusionPath $path -ErrorAction Stop
            Write-Host "  [OK] Excluido: $path" -ForegroundColor Green
        } catch {
            Write-Host "  [ADVERTENCIA] No se pudo excluir $path : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Procesos de IIS
$iisProcesses = @(
    "w3wp.exe",      # Worker process de IIS
    "inetinfo.exe"   # Proceso principal de IIS (versiones antiguas, pero incluido por compatibilidad)
)

foreach ($process in $iisProcesses) {
    try {
        Add-MpPreference -ExclusionProcess $process -ErrorAction Stop
        Write-Host "  [OK] Excluido proceso: $process" -ForegroundColor Green
    } catch {
        Write-Host "  [ADVERTENCIA] No se pudo excluir proceso $process : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Configuración completada ===" -ForegroundColor Green
Write-Host ""
Write-Host "RESUMEN:" -ForegroundColor Cyan
Write-Host "  ✓ Extensiones globales (.mdf, .ndf, .ldf, .bak, .trn, .trc) cubren TODAS las ubicaciones" -ForegroundColor Green
Write-Host "    Esto incluye ubicaciones personalizadas como E:\SQLDATA, D:\SQLData, etc." -ForegroundColor Gray
Write-Host "  ✓ Procesos críticos de SQL Server e IIS excluidos" -ForegroundColor Green
Write-Host "  ✓ Directorios de configuración y binarios excluidos" -ForegroundColor Green
Write-Host ""
Write-Host "Referencia: Microsoft Learn - Antivirus and SQL Server" -ForegroundColor Gray

Read-Host "`nPresiona Enter para salir"

