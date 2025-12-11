# Limpiar la consola
Clear-Host

# Ejecutar desde PowerShell como administrador
Set-Location -Path $PSScriptRoot

# Cargar funciones comunes
. .\Functions.ps1

# Cargar funciones de datos del cliente
. .\ClientData.ps1

# Obtener datos del cliente (con persistencia)
$clientData = Get-ClientData
$client_code = $clientData.client_code
$client_string = $clientData.client_string
$client_name = $clientData.client_name

# Mostrar menú de opciones
Write-Host ""
Write-Host "=========================================" -ForegroundColor DarkGray
Write-Host "          MENÚ DE INSTALACIÓN            " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor DarkGray
Write-Host "U - Update" -ForegroundColor Yellow
Write-Host "-----------------------------------------" -ForegroundColor DarkGray
Write-Host "A - Ejecutar TODOS los módulos siguientes en orden" -ForegroundColor Green
Write-Host "1 - Utilities" -ForegroundColor Yellow
Write-Host "2 - SQL" -ForegroundColor Yellow
Write-Host "3 - Firewall" -ForegroundColor Yellow
Write-Host "4 - IIS" -ForegroundColor Yellow
Write-Host "5 - Users" -ForegroundColor Yellow
Write-Host "6 - ComputerRename" -ForegroundColor Yellow
Write-Host "7 - Activate" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor DarkGray

$opcion = Read-Host "Ingresá una opción (U/A/1-6)"

switch ($opcion) {
    "A" {
        . .\Utilities.ps1
        . .\SQL.ps1
        . .\Firewall.ps1
        . .\IIS.ps1
        . .\Users.ps1
        . .\ComputerRename.ps1
        . .\Activate.ps1
    }
    "U" { . .\Update.ps1 }
    "1" { . .\Utilities.ps1 }
    "2" { . .\SQL.ps1 }
    "3" { . .\Firewall.ps1 }
    "4" { . .\IIS.ps1 }
    "5" { . .\Users.ps1 }
    "6" { . .\ComputerRename.ps1 }
    "7" { . .\Activate.ps1 }
    default {
        Write-Host "Opción inválida. Finalizando." -ForegroundColor Red
        exit
    }
}

# Reinicio opcional
do {
    $respuesta = Read-Host "¿Deseás reiniciar el equipo ahora? (S/N)"
} while ($respuesta -notmatch "^[SsNn]$")

if ($respuesta -match "^[Ss]$") {
    Write-Host "Reiniciando el equipo..." -ForegroundColor Yellow
    Restart-Computer -Force
} else {
    Write-Host "Reinicio omitido." -ForegroundColor Gray
}
