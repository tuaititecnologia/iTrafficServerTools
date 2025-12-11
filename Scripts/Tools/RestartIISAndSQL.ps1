# Script para reiniciar IIS y SQL Server
# Orden de ejecución: Stop IIS -> Stop SQL -> Start SQL -> Start IIS

Write-Host "=== Deteniendo IIS ===" -ForegroundColor Yellow
try {
    iisreset /stop
    Write-Host "IIS detenido correctamente" -ForegroundColor Green
    Start-Sleep -Seconds 3
} catch {
    Write-Host "Error al detener IIS: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Deteniendo SQL Server ===" -ForegroundColor Yellow
# Intentar detener el servicio de SQL Server (instancia por defecto)
$sqlService = Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue
if ($sqlService) {
    try {
        Stop-Service -Name "MSSQLSERVER" -Force
        Write-Host "SQL Server (MSSQLSERVER) detenido correctamente" -ForegroundColor Green
        Start-Sleep -Seconds 3
    } catch {
        Write-Host "Error al detener SQL Server: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    # Buscar servicios de SQL Server con nombres de instancia
    $sqlServices = Get-Service | Where-Object { $_.Name -like "MSSQL$*" -or $_.DisplayName -like "*SQL Server*" }
    if ($sqlServices) {
        foreach ($service in $sqlServices) {
            try {
                Write-Host "Deteniendo servicio: $($service.DisplayName)" -ForegroundColor Cyan
                Stop-Service -Name $service.Name -Force
                Write-Host "  Servicio detenido correctamente" -ForegroundColor Green
                Start-Sleep -Seconds 2
            } catch {
                Write-Host "  Error al detener $($service.DisplayName): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "No se encontraron servicios de SQL Server" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Iniciando SQL Server ===" -ForegroundColor Yellow
# Intentar iniciar el servicio de SQL Server (instancia por defecto)
if ($sqlService) {
    try {
        Start-Service -Name "MSSQLSERVER"
        Write-Host "SQL Server (MSSQLSERVER) iniciado correctamente" -ForegroundColor Green
        Start-Sleep -Seconds 5
    } catch {
        Write-Host "Error al iniciar SQL Server: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    # Iniciar servicios de SQL Server encontrados anteriormente
    if ($sqlServices) {
        foreach ($service in $sqlServices) {
            try {
                Write-Host "Iniciando servicio: $($service.DisplayName)" -ForegroundColor Cyan
                Start-Service -Name $service.Name
                Write-Host "  Servicio iniciado correctamente" -ForegroundColor Green
                Start-Sleep -Seconds 3
            } catch {
                Write-Host "  Error al iniciar $($service.DisplayName): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "`n=== Iniciando IIS ===" -ForegroundColor Yellow
try {
    iisreset /start
    Write-Host "IIS iniciado correctamente" -ForegroundColor Green
} catch {
    Write-Host "Error al iniciar IIS: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Proceso completado ===" -ForegroundColor Green
Write-Host "IIS y SQL Server han sido reiniciados correctamente" -ForegroundColor Green

