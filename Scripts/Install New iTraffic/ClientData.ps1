lientData.ps1 - Manejo de datos del cliente con persistencia

# Archivo de configuración del cliente
$configFile = Join-Path $PSScriptRoot "client_config.json"

function Get-ClientData {
    <#
    .SYNOPSIS
    Obtiene los datos del cliente, cargando desde archivo si existe o solicitando al usuario
    #>
    
    # Verificar si existe archivo de configuración
    if (Test-Path $configFile) {
        try {
            $savedData = Get-Content $configFile -Raw | ConvertFrom-Json
            
            Write-Host "=== DATOS DEL CLIENTE GUARDADOS ===" -ForegroundColor Green
            Write-Host "Código: $($savedData.client_code)" -ForegroundColor Cyan
            Write-Host "Carpeta: $($savedData.client_string)" -ForegroundColor Cyan
            Write-Host "Nombre: $($savedData.client_name)" -ForegroundColor Cyan
            Write-Host ""
            
            do {
                $useSaved = Read-Host "¿Usar estos datos guardados? (S/N)"
            } while ($useSaved -notmatch "^[SsNn]$")
            
            if ($useSaved -match "^[Ss]$") {
                return $savedData
            }
        }
        catch {
            Write-Host "Error al cargar datos guardados. Solicitando datos nuevos..." -ForegroundColor Yellow
        }
    }
    
    # Solicitar datos del cliente
    Write-Host "=== DATOS DEL CLIENTE ===" -ForegroundColor Green
    
    do {
        $client_code = Read-Host "Ingresá el código del cliente (3 letras o números en MAYÚSCULA)"
    } while (-not ($client_code -match "^[A-Z0-9]{3}$"))
    
    do {
        $client_string = Read-Host "Ingresá el nombre de carpeta del cliente (minúsculas y números, sin espacios)"
    } while (-not ($client_string -match "^[a-z0-9]+$"))
    
    $client_name = Read-Host "Ingresá el nombre del cliente"
    
    # Crear objeto con los datos
    $clientData = [PSCustomObject]@{
        client_code = $client_code
        client_string = $client_string
        client_name = $client_name
        last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    # Guardar datos
    Save-ClientData -ClientData $clientData
    
    return $clientData
}

function Save-ClientData {
    <#
    .SYNOPSIS
    Guarda los datos del cliente en archivo JSON
    .PARAMETER ClientData
    Objeto con los datos del cliente
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ClientData
    )
    
    try {
        $ClientData | ConvertTo-Json -Depth 2 | Set-Content $configFile -Encoding UTF8
        Write-Host "Datos del cliente guardados en: $configFile" -ForegroundColor Green
    }
    catch {
        Write-Host "Error al guardar datos del cliente: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Clear-ClientData {
    <#
    .SYNOPSIS
    Elimina los datos guardados del cliente
    #>
    
    if (Test-Path $configFile) {
        try {
            Remove-Item $configFile -Force
            Write-Host "Datos del cliente eliminados." -ForegroundColor Green
        }
        catch {
            Write-Host "Error al eliminar datos del cliente: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "No hay datos del cliente guardados." -ForegroundColor Yellow
    }
}

# Exportar funciones para uso en otros scripts
Export-ModuleMember -Function Get-ClientData, Save-ClientData, Clear-ClientData
