# ============================================================================
# Script de Desinstalación de Aplicaciones
# ============================================================================
# Este script permite desinstalar aplicaciones mediante un menú interactivo
# ============================================================================

# Requiere ejecución como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "  ERROR: Permisos Insuficientes" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Este script requiere ejecutarse como Administrador." -ForegroundColor Yellow
    Write-Host "Por favor, ejecute PowerShell como Administrador e intente nuevamente." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

# ============================================================================
# Funciones Auxiliares
# ============================================================================

function Uninstall-PRTG {
    <#
    .SYNOPSIS
    Desinstala PRTG Network Monitor silenciosamente.
    #>
    Write-Host "`nDesinstalando PRTG Network Monitor..." -ForegroundColor Yellow
    
    # Buscar PRTG en el registro
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $productCode = $null
    
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $app = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
                $_.DisplayName -and ($_.DisplayName -like "*PRTG*" -or $_.DisplayName -like "*Paessler*")
            } | Select-Object -First 1
            
            if ($app) {
                $productCode = $app.PSChildName
                Write-Host "  Encontrado: $($app.DisplayName)" -ForegroundColor Green
                if ($app.DisplayVersion) {
                    Write-Host "  Versión: $($app.DisplayVersion)" -ForegroundColor Gray
                }
                break
            }
        }
    }
    
    if (-not $productCode) {
        Write-Host "  PRTG Network Monitor no está instalado en el sistema." -ForegroundColor Red
        return $false
    }
    
    # Desinstalar usando msiexec con ProductCode (GUID) - método silencioso estándar
    Write-Host "  Desinstalando silenciosamente..." -ForegroundColor Gray
    try {
        Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/x", "$productCode", "/quiet", "/norestart" -NoNewWindow
        Write-Host "  PRTG Network Monitor desinstalado exitosamente." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  Error al desinstalar: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# Definición de Aplicaciones Disponibles para Desinstalar
# ============================================================================

$availableApplications = @(
    @{
        Name = "PRTG Network Monitor"
        Description = "PRTG Network Monitor - Sistema de monitoreo de red"
        UninstallFunction = { Uninstall-PRTG }
    }
    # Aquí se pueden agregar más aplicaciones en el futuro
    # Ejemplo:
    # @{
    #     Name = "Otra Aplicación"
    #     Description = "Descripción de la aplicación"
    #     UninstallFunction = { Uninstall-OtraAplicacion }
    # }
)

# ============================================================================
# Menú Principal
# ============================================================================

function Show-Menu {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  DESINSTALADOR DE APLICACIONES" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Aplicaciones disponibles para desinstalar:" -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $availableApplications.Count; $i++) {
        $app = $availableApplications[$i]
        $number = $i + 1
        Write-Host "  [$number] $($app.Name)" -ForegroundColor Yellow
        Write-Host "      $($app.Description)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  [0] Salir" -ForegroundColor Gray
    Write-Host ""
}

function Process-UninstallSelection {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Selection
    )
    
    if ($Selection -lt 1 -or $Selection -gt $availableApplications.Count) {
        Write-Host "Selección inválida." -ForegroundColor Red
        return
    }
    
    $selectedApp = $availableApplications[$Selection - 1]
    
    # Confirmar desinstalación
    Write-Host ""
    Write-Host "Aplicación seleccionada: $($selectedApp.Name)" -ForegroundColor Cyan
    Write-Host ""
    
    $confirmation = Read-Host "¿Está seguro de que desea desinstalar esta aplicación? (S/N)"
    if ($null -eq $confirmation) {
        $confirmation = ""
    }
    $confirmationClean = $confirmation.Trim().ToUpperInvariant()
    
    if ($confirmationClean -notin @("S", "SI", "Y", "YES")) {
        Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
        return
    }
    
    # Ejecutar la función de desinstalación
    $success = & $selectedApp.UninstallFunction
    
    if ($success) {
        Write-Host ""
        Write-Host "Desinstalación completada." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Hubo problemas durante la desinstalación." -ForegroundColor Red
        Write-Host "Puede que necesite desinstalar manualmente desde el Panel de Control." -ForegroundColor Yellow
    }
}

# ============================================================================
# Script Principal
# ============================================================================

Write-Host ""
Write-Host "=== Script de Desinstalación de Aplicaciones ===" -ForegroundColor Cyan
Write-Host ""

do {
    Show-Menu
    
    $selection = Read-Host "Seleccione una opción"
    
    try {
        $selectionNum = [int]$selection
        
        if ($selectionNum -eq 0) {
            Write-Host ""
            Write-Host "Saliendo..." -ForegroundColor Yellow
            break
        } else {
            Process-UninstallSelection -Selection $selectionNum
            Write-Host ""
            $continue = Read-Host "¿Desea desinstalar otra aplicación? (S/N)"
            if ($null -eq $continue) {
                $continue = ""
            }
            $continueClean = $continue.Trim().ToUpperInvariant()
            if ($continueClean -notin @("S", "SI", "Y", "YES")) {
                break
            }
        }
    } catch {
        Write-Host "Entrada inválida. Por favor ingrese un número." -ForegroundColor Red
        Write-Host ""
    }
} while ($true)

Write-Host ""
Write-Host "=== Proceso Finalizado ===" -ForegroundColor Cyan
Write-Host ""

# Solo pausar si se ejecuta de forma interactiva
if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
    pause
}
