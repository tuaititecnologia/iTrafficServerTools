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
        $currentTask = Get-ScheduledTask -TaskName $taskName
        $currentTrigger = $currentTask.Triggers[0]
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
        # Menú cuando la tarea existe
        Write-Host "Opciones:" -ForegroundColor White
        Write-Host "  [N] Salir - Salir sin realizar cambios" -ForegroundColor Gray
        Write-Host "  [M] Modificar - Cambiar la fecha y hora de ejecución" -ForegroundColor Yellow
        Write-Host "  [E] Eliminar - Eliminar la tarea programada" -ForegroundColor Red
    } else {
        # Menú cuando la tarea NO existe
        Write-Host "Fecha y hora propuesta: $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Opciones:" -ForegroundColor White
        Write-Host "  [S] Crear - Crear la tarea con la fecha y hora propuesta" -ForegroundColor Green
        Write-Host "  [M] Modificar - Cambiar la fecha y hora antes de crear" -ForegroundColor Yellow
        Write-Host "  [N] Salir - Cancelar y salir sin crear la tarea" -ForegroundColor Gray
    }
    Write-Host ""
}

# Solicitar confirmación
$confirmation = ""

if ($existingTask) {
    # Si la tarea existe: N (salir), M (modificar), E (eliminar)
    $validOptions = @("N", "NO", "M", "MODIFICAR", "MODIFY", "E", "ELIMINAR", "DELETE", "DEL")
    
    do {
        Show-Menu
        $input = Read-Host "Seleccione una opción (N/M/E)"
        if ($null -eq $input) {
            $input = ""
        }
        $confirmation = $input.Trim().ToUpperInvariant()
        
        if ($confirmation -eq "M" -or $confirmation -eq "MODIFICAR" -or $confirmation -eq "MODIFY") {
            # Solicitar fecha y hora personalizada
            Write-Host ""
            Write-Host "Ingrese la nueva fecha y hora para el reinicio:" -ForegroundColor Cyan
            Write-Host "Formato esperado: $dateTimeFormat" -ForegroundColor Gray
            Write-Host "Ejemplo: $dateTimeExample" -ForegroundColor Gray
            Write-Host ""
            
            $dateInput = Read-Host "Fecha y hora"
            if ($null -eq $dateInput) {
                $dateInput = ""
            }
            $dateInput = $dateInput.Trim()
            
            if ($dateInput -ne "") {
                try {
                    # Parsear la fecha usando el formato del sistema operativo
                    $parsedDate = [DateTime]::Parse($dateInput, $culture)
                    
                    # Verificar que la fecha sea en el futuro
                    if ($parsedDate -le $now) {
                        Write-Host "  Error: La fecha y hora deben ser en el futuro." -ForegroundColor Red
                        Write-Host "  Fecha/hora actual: $($now.ToString($dateTimeFormat))" -ForegroundColor Yellow
                        Write-Host ""
                        continue
                    }
                    
                    $scheduledDateTime = $parsedDate
                    Write-Host ""
                    Write-Host "Fecha y hora establecida: $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Green
                    Write-Host ""
                    
                    # Después de cambiar la fecha, proceder a actualizar
                    $confirmation = "M_CONFIRM"
                    break
                } catch {
                    Write-Host "  Error: No se pudo interpretar la fecha y hora ingresada." -ForegroundColor Red
                    Write-Host "  Por favor, use el formato: $dateTimeFormat" -ForegroundColor Yellow
                    Write-Host "  Ejemplo: $dateTimeExample" -ForegroundColor Yellow
                    Write-Host ""
                }
            } else {
                Write-Host "  Error: Debe ingresar una fecha y hora." -ForegroundColor Red
                Write-Host ""
            }
        } elseif ($confirmation -notin $validOptions) {
            Write-Host "Opción inválida. Por favor seleccione N, M o E." -ForegroundColor Red
            Write-Host ""
        }
    } while ($confirmation -notin @("N", "NO", "E", "ELIMINAR", "DELETE", "DEL", "M_CONFIRM"))
} else {
    # Si la tarea NO existe: S (crear), M (modificar), N (salir)
    $validOptions = @("S", "SI", "Y", "YES", "CREAR", "CREATE", "M", "MODIFICAR", "MODIFY", "N", "NO")
    
    do {
        Show-Menu
        $input = Read-Host "Seleccione una opción (S/M/N)"
        if ($null -eq $input) {
            $input = ""
        }
        $confirmation = $input.Trim().ToUpperInvariant()
        
        if ($confirmation -eq "M" -or $confirmation -eq "MODIFICAR" -or $confirmation -eq "MODIFY") {
            # Solicitar fecha y hora personalizada
            Write-Host ""
            Write-Host "Ingrese la fecha y hora deseada para el reinicio:" -ForegroundColor Cyan
            Write-Host "Formato esperado: $dateTimeFormat" -ForegroundColor Gray
            Write-Host "Ejemplo: $dateTimeExample" -ForegroundColor Gray
            Write-Host ""
            
            $dateInput = Read-Host "Fecha y hora"
            if ($null -eq $dateInput) {
                $dateInput = ""
            }
            $dateInput = $dateInput.Trim()
            
            if ($dateInput -ne "") {
                try {
                    # Parsear la fecha usando el formato del sistema operativo
                    $parsedDate = [DateTime]::Parse($dateInput, $culture)
                    
                    # Verificar que la fecha sea en el futuro
                    if ($parsedDate -le $now) {
                        Write-Host "  Error: La fecha y hora deben ser en el futuro." -ForegroundColor Red
                        Write-Host "  Fecha/hora actual: $($now.ToString($dateTimeFormat))" -ForegroundColor Yellow
                        Write-Host ""
                        continue
                    }
                    
                    $scheduledDateTime = $parsedDate
                    Write-Host ""
                    Write-Host "Fecha y hora actualizada correctamente." -ForegroundColor Green
                    Write-Host ""
                } catch {
                    Write-Host "  Error: No se pudo interpretar la fecha y hora ingresada." -ForegroundColor Red
                    Write-Host "  Por favor, use el formato: $dateTimeFormat" -ForegroundColor Yellow
                    Write-Host "  Ejemplo: $dateTimeExample" -ForegroundColor Yellow
                    Write-Host ""
                }
            } else {
                Write-Host "  Error: Debe ingresar una fecha y hora." -ForegroundColor Red
                Write-Host ""
            }
        } elseif ($confirmation -notin $validOptions) {
            Write-Host "Opción inválida. Por favor seleccione S, M o N." -ForegroundColor Red
            Write-Host ""
        }
    } while ($confirmation -notin @("S", "SI", "Y", "YES", "CREAR", "CREATE", "N", "NO"))
}

# Procesar la respuesta
if ($confirmation -in @("N", "NO")) {
    Write-Host ""
    Write-Host "Operación cancelada. No se realizaron cambios." -ForegroundColor Yellow
    Write-Host ""
    if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
        pause
    }
    exit 0
}

# Procesar eliminación de tarea (solo si existe)
if ($existingTask -and $confirmation -in @("E", "ELIMINAR", "DELETE", "DEL")) {
    Write-Host ""
    Write-Host "Eliminando tarea programada '$taskName'..." -ForegroundColor Cyan
    
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "  Tarea programada '$taskName' eliminada exitosamente." -ForegroundColor Green
        Write-Host ""
        Write-Host "=== Proceso Finalizado ===" -ForegroundColor Cyan
        Write-Host ""
        if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
            pause
        }
        exit 0
    } catch {
        Write-Host "  Error al eliminar la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
            pause
        }
        exit 1
    }
}

# Proceder con la creación o actualización
Write-Host ""

# Si la tarea existe y se eligió modificar (M_CONFIRM), actualizar
if ($existingTask -and $confirmation -eq "M_CONFIRM") {
    Write-Host "Actualizando tarea programada '$taskName'..." -ForegroundColor Cyan
    
    try {
        # Obtener la tarea completa
        $task = Get-ScheduledTask -TaskName $taskName
        
        # Crear un nuevo trigger con la nueva fecha/hora
        $newTrigger = New-ScheduledTaskTrigger -Once -At $scheduledDateTime
        # Establecer EndBoundary para evitar el error XML (un día después de la ejecución)
        $newTrigger.EndBoundary = $scheduledDateTime.AddDays(1).ToString("yyyy-MM-ddTHH:mm:ss")
        
        # Obtener la acción actual (puede ser un array, tomar el primer elemento)
        if ($task.Actions -is [System.Array]) {
            $currentAction = $task.Actions[0]
        } else {
            $currentAction = $task.Actions
        }
        
        # Obtener la configuración actual como objeto TaskSettings
        $currentSettings = $task.Settings
        
        # Obtener el principal actual
        $currentPrincipal = $task.Principal
        
        # Actualizar la tarea - usar el objeto Task completo para evitar problemas de conversión
        # Primero, actualizar solo el trigger (método más seguro)
        $task.Triggers = @($newTrigger)
        
        # Actualizar la descripción si es necesario
        $task.Description = "Reinicio programado del servidor. Ejecuta 'shutdown -r -t 0'."
        
        # Registrar la tarea actualizada
        Set-ScheduledTask -InputObject $task
        
        Write-Host "  Tarea programada '$taskName' actualizada exitosamente." -ForegroundColor Green
        Write-Host "  El servidor se reiniciará el $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Green
        Write-Host ""
        Write-Host "=== Proceso Finalizado ===" -ForegroundColor Cyan
        Write-Host ""
        if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
            pause
        }
        exit 0
    } catch {
        Write-Host "  Error al actualizar la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Intentando método alternativo..." -ForegroundColor Yellow
        
        try {
            # Método alternativo: eliminar y recrear la tarea
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            
            # Crear la acción para ejecutar el comando de reinicio
            $action = New-ScheduledTaskAction -Execute "shutdown.exe" `
                -Argument "-r -t 0"
            
            # Configurar el trigger para ejecutarse una vez en la fecha y hora especificada
            $trigger = New-ScheduledTaskTrigger -Once -At $scheduledDateTime
            # Establecer EndBoundary para evitar el error XML (un día después de la ejecución)
            $trigger.EndBoundary = $scheduledDateTime.AddDays(1).ToString("yyyy-MM-ddTHH:mm:ss")
            
            # Configurar la configuración de la tarea
            $settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -RunOnlyIfNetworkAvailable:$false `
                -DeleteExpiredTaskAfter (New-TimeSpan -Days 0) `
                -ExecutionTimeLimit (New-TimeSpan -Minutes 0)
            
            # Crear el principal (usuario que ejecuta la tarea)
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
                -Description "Reinicio programado del servidor. Ejecuta 'shutdown -r -t 0'." `
                -Force
            
            Write-Host "  Tarea programada '$taskName' recreada exitosamente." -ForegroundColor Green
            Write-Host "  El servidor se reiniciará el $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Green
            Write-Host ""
            Write-Host "=== Proceso Finalizado ===" -ForegroundColor Cyan
            Write-Host ""
            if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
                pause
            }
            exit 0
        } catch {
            Write-Host "  Error al recrear la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "=== Proceso Finalizado ===" -ForegroundColor Cyan
            Write-Host ""
            if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
                pause
            }
            exit 1
        }
    }
} elseif (-not $existingTask -and $confirmation -in @("S", "SI", "Y", "YES", "CREAR", "CREATE")) {
    # Crear nueva tarea solo si no existe y se seleccionó crear
    Write-Host "Creando tarea programada '$taskName'..." -ForegroundColor Cyan
    
    try {
        # Crear la acción para ejecutar el comando de reinicio
        $action = New-ScheduledTaskAction -Execute "shutdown.exe" `
            -Argument "-r -t 0"
        
        # Configurar el trigger para ejecutarse una vez en la fecha y hora especificada
        $trigger = New-ScheduledTaskTrigger -Once -At $scheduledDateTime
        # Establecer EndBoundary para evitar el error XML (un día después de la ejecución)
        $trigger.EndBoundary = $scheduledDateTime.AddDays(1).ToString("yyyy-MM-ddTHH:mm:ss")
        
        # Configurar la configuración de la tarea
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable:$false `
            -DeleteExpiredTaskAfter (New-TimeSpan -Days 0) `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 0)
        
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
            -Description "Reinicio programado del servidor. Ejecuta 'shutdown -r -t 0'." `
            -Force
        
        Write-Host "  Tarea programada '$taskName' creada exitosamente." -ForegroundColor Green
        Write-Host "  El servidor se reiniciará el $($scheduledDateTime.ToString($dateTimeFormat))" -ForegroundColor Green
        Write-Host ""
        Write-Host "=== Proceso Finalizado ===" -ForegroundColor Cyan
        Write-Host ""
        if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
            pause
        }
        exit 0
    } catch {
        Write-Host "  Error al crear la tarea programada: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "=== Proceso Finalizado ===" -ForegroundColor Cyan
        Write-Host ""
        if ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
            pause
        }
        exit 1
    }
}

