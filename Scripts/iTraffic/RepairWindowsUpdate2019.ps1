# Verificar si la tarea ya existe
$taskName = "WindowsUpdateReboot"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "=== ADVERTENCIA ===" -ForegroundColor Yellow
    Write-Host "Este script ya se ejecutó previamente. Abortando..." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Deteniendo servicios de Windows Update ==="
Stop-Service wuauserv -Force
Stop-Service bits -Force
Stop-Service cryptsvc -Force

Write-Host "=== Renombrando carpetas del sistema ==="
Rename-Item "C:\Windows\SoftwareDistribution" "SoftwareDistribution.bak" -Force -ErrorAction SilentlyContinue
Rename-Item "C:\Windows\System32\catroot2" "catroot2.bak" -Force -ErrorAction SilentlyContinue

Write-Host "=== Iniciando servicios nuevamente ==="
Start-Service cryptsvc
Start-Service bits
Start-Service wuauserv

Start-Sleep -Seconds 5

Write-Host "=== Borrando carpetas viejas ==="
Remove-Item -Recurse -Force "C:\Windows\SoftwareDistribution.bak" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "C:\Windows\System32\catroot2.bak" -ErrorAction SilentlyContinue

Write-Host "=== Creando tarea programada para reinicio ==="
# Calcular la próxima medianoche (00:00 de mañana)
$nextMidnight = (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(1)

# Crear la acción: reiniciar el servidor
$action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /f /t 0"

# Crear el trigger: ejecutar una sola vez a las 00:00 con delay aleatorio de 8 horas
$trigger = New-ScheduledTaskTrigger -Once -At $nextMidnight -RandomDelay (New-TimeSpan -Hours 8)

# Configuración de la tarea para que se ejecute con privilegios máximos
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Registrar la tarea programada
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

Write-Host "Tarea '$taskName' creada exitosamente"
Write-Host "Se ejecutará a las 00:00 con un delay aleatorio de hasta 8 horas"
