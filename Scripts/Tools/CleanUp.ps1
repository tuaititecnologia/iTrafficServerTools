 # ============================================================================
# Auto-configuración como Tarea Programada
# ============================================================================
$taskName = "iTraffic-CleanUp"
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDirectory = Split-Path -Parent $scriptPath

# Verificar si la tarea programada ya existe
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $existingTask) {
    Write-Host "Configurando tarea programada '$taskName'..." -ForegroundColor Cyan
    
    try {
        # Crear la acción para ejecutar el script
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        
        # Configurar el trigger para ejecutarse diariamente a las 2:00 AM
        $trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM
        
        # Configurar la configuración de la tarea
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable:$false
        
        # Crear el principal (usuario que ejecuta la tarea)
        # Usar el usuario actual con tipo de inicio de sesión S4U (no requiere contraseña)
        $principal = New-ScheduledTaskPrincipal `
            -UserId "$env:USERDOMAIN\$env:USERNAME" `
            -LogonType S4U `
            -RunLevel Highest
        
        # Registrar la tarea programada
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "Limpieza automática de logs y archivos temporales de iTraffic. Ejecuta el script CleanUp.ps1 diariamente a las 2:00 AM." `
            -Force
        
        Write-Host "  Tarea programada '$taskName' creada exitosamente." -ForegroundColor Green
        Write-Host "  Se ejecutará diariamente a las 2:00 AM." -ForegroundColor Green
    } catch {
        Write-Host "  Error al crear la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  El script continuará ejecutándose normalmente." -ForegroundColor Yellow
    }
} else {
    Write-Host "La tarea programada '$taskName' ya está configurada." -ForegroundColor Gray
}

Write-Host ""

# ============================================================================
# Helpers
# ============================================================================
function Restart-ServiceIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host "Servicio '$Name' no encontrado. Se omite reinicio." -ForegroundColor Gray
        return
    }

    try {
        Restart-Service -Name $Name -ErrorAction Stop
        Write-Host "Servicio '$Name' reiniciado." -ForegroundColor Green
    } catch {
        Write-Host "No se pudo reiniciar el servicio '$Name': $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ============================================================================
# Limpieza de Logs y Archivos Temporales
# ============================================================================

# Eliminar logs de todas las aplicaciones en wwwroot
$wwwrootPath = "C:\inetpub\wwwroot"
$logFolders = Get-ChildItem -Path $wwwrootPath -Recurse -Directory -Filter "Log" | Where-Object { $_.FullName -like "*\App_Data\Log" }

foreach ($logFolder in $logFolders) {
    Write-Host "Limpiando logs en: $($logFolder.FullName)" -ForegroundColor Yellow
    $filesToDelete = Get-ChildItem -Path $logFolder.FullName -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) }
    if ($filesToDelete) {
        $filesToDelete | Remove-Item -Force
        Write-Host "  Eliminados $($filesToDelete.Count) archivo(s)" -ForegroundColor Green
    } else {
        Write-Host "  No se encontraron archivos para eliminar" -ForegroundColor Gray
    }
}

# Eliminar archivos con formato yyyy.m.d.h.m.s.zip en carpetas de aplicación dentro de wwwroot
Write-Host "`nEliminando archivos con formato yyyy.m.d.h.m.s.zip en wwwroot..." -ForegroundColor Yellow
$appFolders = Get-ChildItem -Path $wwwrootPath -Directory
$pattern = '^\d{4}\.\d{1,2}\.\d{1,2}\.\d{1,2}\.\d{1,2}\.\d{1,2}\.zip$'
$totalDeleted = 0

foreach ($appFolder in $appFolders) {
    $zipFiles = Get-ChildItem -Path $appFolder.FullName -Filter "*.zip" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $pattern }
    if ($zipFiles) {
        Write-Host "  Encontrados archivos en: $($appFolder.Name)" -ForegroundColor Cyan
        foreach ($file in $zipFiles) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                $totalDeleted++
                Write-Host "    Eliminado: $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "    No se pudo eliminar $($file.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

if ($totalDeleted -gt 0) {
    Write-Host "  Total eliminados: $totalDeleted archivo(s)" -ForegroundColor Green
} else {
    Write-Host "  No se encontraron archivos con el formato especificado" -ForegroundColor Gray
}

# Eliminar logs de IIS en todas las subcarpetas de LogFiles
$iisLogPath = "C:\inetpub\logs\LogFiles"
$iisLogFolders = Get-ChildItem -Path $iisLogPath -Directory

foreach ($iisFolder in $iisLogFolders) {
    Write-Host "Limpiando logs de IIS en: $($iisFolder.FullName)" -ForegroundColor Yellow
    $filesToDelete = Get-ChildItem -Path $iisFolder.FullName -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) }
    if ($filesToDelete) {
        $filesToDelete | Remove-Item -Force
        Write-Host "  Eliminados $($filesToDelete.Count) archivo(s)" -ForegroundColor Green
    } else {
        Write-Host "  No se encontraron archivos para eliminar" -ForegroundColor Gray
    }
}

# Eliminar logs de SpoolfisNet
Restart-ServiceIfExists -Name "SpoolfisNet"
Restart-ServiceIfExists -Name "SpoolfisNetV2Service"
$programFilesPaths = @("C:\Program Files", "C:\Program Files (x86)")

foreach ($programPath in $programFilesPaths) {
    if (Test-Path $programPath) {
        $spoolfisFolders = Get-ChildItem -Path $programPath -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Spoolfis*" }
        
        foreach ($spoolfisFolder in $spoolfisFolders) {
            Write-Host "Limpiando logs de SpoolfisNet en: $($spoolfisFolder.FullName)" -ForegroundColor Yellow
            $filesToDelete = Get-ChildItem -Path $spoolfisFolder.FullName -Filter "*.txt.*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "log-file.txt" }
            if ($filesToDelete) {
                $deletedCount = 0
                foreach ($file in $filesToDelete) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        $deletedCount++
                    } catch {
                        Write-Host "  No se pudo eliminar $($file.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
                if ($deletedCount -gt 0) {
                    Write-Host "  Eliminados $deletedCount archivo(s)" -ForegroundColor Green
                }
            } else {
                Write-Host "  No se encontraron archivos para eliminar" -ForegroundColor Gray
            }
        }
    }
}

# Eliminar logs de ServicePriceSurferMigrationReservation (carpeta "logs" dentro del servicio)
foreach ($programPath in $programFilesPaths) {
    if (Test-Path $programPath) {
        $serviceFolders = Get-ChildItem -Path $programPath -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq "ServicePriceSurferMigrationReservation" }

        foreach ($serviceFolder in $serviceFolders) {
            $logsPath = Join-Path $serviceFolder.FullName "logs"
            if (Test-Path $logsPath) {
                Write-Host "Limpiando logs de ServicePriceSurferMigrationReservation en: $logsPath" -ForegroundColor Yellow
                $filesToDelete = Get-ChildItem -Path $logsPath -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) }

                if ($filesToDelete) {
                    $deletedCount = 0
                    foreach ($file in $filesToDelete) {
                        try {
                            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                            $deletedCount++
                        } catch {
                            Write-Host "  No se pudo eliminar $($file.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                    if ($deletedCount -gt 0) {
                        Write-Host "  Eliminados $deletedCount archivo(s)" -ForegroundColor Green
                    }
                } else {
                    Write-Host "  No se encontraron archivos para eliminar" -ForegroundColor Gray
                }
            }
        }
    }
}

# Limpiar carpeta barcode
Get-ChildItem -Path "C:\inetpub\barcode\*.*" | Remove-Item

# Vaciar papelera de reciclaje
Write-Host "`nLimpiando papelera de reciclaje (C:)..." -ForegroundColor Yellow
try {
    Clear-RecycleBin -DriveLetter C -Force -ErrorAction Stop
    Write-Host "  Papelera vaciada correctamente" -ForegroundColor Green
} catch {
    Write-Host "  No se pudo vaciar la papelera con Clear-RecycleBin: $($_.Exception.Message)" -ForegroundColor Yellow
    # Intentar eliminar contenido directamente de $Recycle.bin
    $recycleBinPath = "C:\`$Recycle.bin"
    if (Test-Path $recycleBinPath) {
        try {
            Get-ChildItem -Path $recycleBinPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "  Contenido de `$Recycle.bin eliminado manualmente" -ForegroundColor Green
        } catch {
            Write-Host "  No se pudo eliminar el contenido de `$Recycle.bin: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  No se encontró la carpeta `$Recycle.bin" -ForegroundColor Gray
    }
}

# Mostrar información del disco C:
Write-Host "`n=== Información del Disco C: ===" -ForegroundColor Cyan
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
if ($disk) {
    $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
    $usedSpaceGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
    $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $percentUsed = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
    
    Write-Host "Espacio Total:     $totalSpaceGB GB" -ForegroundColor White
    Write-Host "Espacio Utilizado: $usedSpaceGB GB" -ForegroundColor White
    Write-Host "Espacio Libre:     $freeSpaceGB GB" -ForegroundColor White
    Write-Host "Porcentaje Ocupado: $percentUsed%" -ForegroundColor $(if ($percentUsed -gt 90) { "Red" } elseif ($percentUsed -gt 80) { "Yellow" } else { "Green" })
} else {
    Write-Host "No se pudo obtener información del disco C:" -ForegroundColor Red
}

# Solo pausar si se ejecuta de forma interactiva (no como tarea programada)
if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
    pause
}
 
