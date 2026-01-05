# ============================================================================
# Script de Configuración de Tarea Programada para Reinicio
# ============================================================================
# Este script configura una tarea programada para reiniciar el servidor
# a las 2:00 AM del día siguiente al actual
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
# Configuración de Tarea Programada
# ============================================================================
$taskName = "Reboot"

# Obtener el formato de fecha/hora del sistema operativo
$culture = [System.Globalization.CultureInfo]::CurrentCulture
$dateFormat = $culture.DateTimeFormat.ShortDatePattern
$timeFormat = $culture.DateTimeFormat.ShortTimePattern
$dateTimeFormat = "$dateFormat $timeFormat"
$dateTimeExample = (Get-Date).ToString($dateTimeFormat)

# Calcular la fecha y hora de ejecución por defecto (2:00 AM del día siguiente)
$now = Get-Date
$scheduledDateTime = $now.AddDays(1).Date.AddHours(2)  # Día siguiente a las 2:00 AM

Write-Host ""
Write-Host "=== Configuración de Tarea Programada de Reinicio ===" -ForegroundColor Cyan
Write-Host ""

# Verificar si la tarea programada ya existe
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "La tarea programada '$taskName' ya existe." -ForegroundColor Yellow
    try {
        $currentTrigger = $existingTask.Triggers[0]
        if ($currentTrigger.StartBoundary) {
            $currentDateTime = [DateTime]::Parse($currentTrigger.StartBoundary)
            Write-Host "Fecha y hora actual programada: $($currentDateTime.ToString($dateTimeFormat))" -ForegroundColor Cyan
            Write-Host ""
        }
    } catch {
        # Si no se puede obtener la fecha actual, continuar
    }
} else {
    Write-Host "La tarea programada '$taskName' no existe. Se creará una nueva." -ForegroundColor Cyan
}

# Función para mostrar el menú según si la tarea existe o no
function Show-Menu {
    if ($existingTask) {
        Write-Host "Opciones:" -ForegroundColor White
        Write-Host "  [N] Salir - Salir sin realizar cambios" -ForegroundColor Gray
        Write-Host "  [M] Modificar - Cambiar la fecha y hora de ejecución" -ForegroundColor Yellow
        Write-Host "  [E] Eliminar - Eliminar la tarea programada" -ForegroundColor Red
    } else {
        Write-Host "Fecha y hora propuesta: $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Opciones:" -ForegroundColor White
        Write-Host "  [S] Crear - Crear la tarea con la fecha y hora propuesta" -ForegroundColor Green
        Write-Host "  [M] Modificar - Cambiar la fecha y hora antes de crear" -ForegroundColor Yellow
        Write-Host "  [N] Salir - Cancelar y salir sin crear la tarea" -ForegroundColor Gray
    }
    Write-Host ""
}

# Función para solicitar y validar fecha/hora
function Get-DateTimeInput {
    Write-Host ""
    Write-Host "Ingrese la fecha y hora deseada para el reinicio:" -ForegroundColor Cyan
    Write-Host "Formato esperado: $dateTimeFormat" -ForegroundColor Gray
    Write-Host "Ejemplo: $dateTimeExample" -ForegroundColor Gray
    Write-Host ""
    
    $dateInput = (Read-Host "Fecha y hora").Trim()
    
    if ([string]::IsNullOrWhiteSpace($dateInput)) {
        Write-Host "  Error: Debe ingresar una fecha y hora." -ForegroundColor Red
        Write-Host ""
        return $null
    }
    
    try {
        $parsedDate = [DateTime]::Parse($dateInput, $culture)
        
        if ($parsedDate -le $now) {
            Write-Host "  Error: La fecha y hora deben ser en el futuro." -ForegroundColor Red
            Write-Host "  Fecha/hora actual: $($now.ToString($dateTimeFormat))" -ForegroundColor Yellow
            Write-Host ""
            return $null
        }
        
        return $parsedDate
    } catch {
        Write-Host "  Error: No se pudo interpretar la fecha y hora ingresada." -ForegroundColor Red
        Write-Host "  Por favor, use el formato: $dateTimeFormat" -ForegroundColor Yellow
        Write-Host "  Ejemplo: $dateTimeExample" -ForegroundColor Yellow
        Write-Host ""
        return $null
    }
}

# Función para crear tarea programada
function New-ScheduledRebootTask {
    param([DateTime]$DateTime)
    
    $action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "-r -t 0"
    $trigger = New-ScheduledTaskTrigger -Once -At $DateTime
    $trigger.EndBoundary = $DateTime.AddDays(1).ToString("yyyy-MM-ddTHH:mm:ss")
    
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable:$false `
        -DeleteExpiredTaskAfter (New-TimeSpan -Days 0) `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 0)
    
    $principal = New-ScheduledTaskPrincipal `
        -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType S4U `
        -RunLevel Highest
    
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Reinicio programado del servidor. Ejecuta 'shutdown -r -t 0'." `
        -Force
}

# Función para finalizar script
function Exit-Script {
    param(
        [int]$ExitCode = 0,
        [string]$Message = "=== Proceso Finalizado ==="
    )
    
    if ($Message) {
        Write-Host ""
        Write-Host $Message -ForegroundColor Cyan
        Write-Host ""
    }
    
    if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
        pause
    }
    exit $ExitCode
}

# Solicitar confirmación
$confirmation = ""

if ($existingTask) {
    do {
        Show-Menu
        $confirmation = (Read-Host "Seleccione una opción (N/M/E)").Trim().ToUpper()
        
        if ($confirmation -eq "M") {
            $newDate = Get-DateTimeInput
            if ($newDate) {
                $scheduledDateTime = $newDate
                Write-Host "Fecha y hora establecida: $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Green
                Write-Host ""
                $confirmation = "M_CONFIRM"
                break
            }
        } elseif ($confirmation -notin @("N", "E")) {
            Write-Host "Opción inválida. Por favor seleccione N, M o E." -ForegroundColor Red
            Write-Host ""
        }
    } while ($confirmation -notin @("N", "E", "M_CONFIRM"))
} else {
    do {
        Show-Menu
        $confirmation = (Read-Host "Seleccione una opción (S/M/N)").Trim().ToUpper()
        
        if ($confirmation -eq "M") {
            $newDate = Get-DateTimeInput
            if ($newDate) {
                $scheduledDateTime = $newDate
                Write-Host "Fecha y hora actualizada correctamente." -ForegroundColor Green
                Write-Host ""
            }
        } elseif ($confirmation -notin @("S", "N")) {
            Write-Host "Opción inválida. Por favor seleccione S, M o N." -ForegroundColor Red
            Write-Host ""
        }
    } while ($confirmation -notin @("S", "N"))
}

# Procesar la respuesta
if ($confirmation -eq "N") {
    Exit-Script -Message "Operación cancelada. No se realizaron cambios." -ExitCode 0
}

if ($existingTask -and $confirmation -eq "E") {
    Write-Host ""
    Write-Host "Eliminando tarea programada '$taskName'..." -ForegroundColor Cyan
    
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "  Tarea programada '$taskName' eliminada exitosamente." -ForegroundColor Green
        Exit-Script
    } catch {
        Write-Host "  Error al eliminar la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
        Exit-Script -ExitCode 1
    }
}

# Proceder con la creación o actualización
Write-Host ""

if ($existingTask -and $confirmation -eq "M_CONFIRM") {
    Write-Host "Actualizando tarea programada '$taskName'..." -ForegroundColor Cyan
    
    try {
        $task = Get-ScheduledTask -TaskName $taskName
        $newTrigger = New-ScheduledTaskTrigger -Once -At $scheduledDateTime
        $newTrigger.EndBoundary = $scheduledDateTime.AddDays(1).ToString("yyyy-MM-ddTHH:mm:ss")
        
        $task.Triggers = @($newTrigger)
        $task.Description = "Reinicio programado del servidor. Ejecuta 'shutdown -r -t 0'."
        Set-ScheduledTask -InputObject $task
        
        Write-Host "  Tarea programada '$taskName' actualizada exitosamente." -ForegroundColor Green
        Write-Host "  El servidor se reiniciará el $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Green
        Exit-Script
    } catch {
        Write-Host "  Error al actualizar la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Intentando método alternativo..." -ForegroundColor Yellow
        
        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            New-ScheduledRebootTask -DateTime $scheduledDateTime
            
            Write-Host "  Tarea programada '$taskName' recreada exitosamente." -ForegroundColor Green
            Write-Host "  El servidor se reiniciará el $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Green
            Exit-Script
        } catch {
            Write-Host "  Error al recrear la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
            Exit-Script -ExitCode 1
        }
    }
} elseif (-not $existingTask -and $confirmation -eq "S") {
    Write-Host "Creando tarea programada '$taskName'..." -ForegroundColor Cyan
    
    try {
        New-ScheduledRebootTask -DateTime $scheduledDateTime
        
        Write-Host "  Tarea programada '$taskName' creada exitosamente." -ForegroundColor Green
        Write-Host "  El servidor se reiniciará el $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Green
        Exit-Script
    } catch {
        Write-Host "  Error al crear la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
        Exit-Script -ExitCode 1
    }
}

