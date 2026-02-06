# Módulo Backup.ps1
# Instala y configura Macrium Reflect Server Plus
# Usa $client_code y $client_string del caché de ClientData.ps1

Import-Module ScheduledTasks

$user_profile = $env:USERPROFILE
$osVersion = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'ProductName').ProductName
$reflectSource = "\\172.21.15.130\TuaitiBackup\Soft\Reflect\Macrium Reflect 8.0.5946 x64 incl Keygen [CrackingPatching]"
$toolsPath = Join-Path $PSScriptRoot "..\Tools"

# Desactivar antivirus temporalmente
if ($osVersion -notmatch 'Windows Server 2012') {
    Write-Host "Desactivando antivirus" -ForegroundColor Yellow
    Set-MpPreference -DisableRealtimeMonitoring $true
}

# Desinstalar programas de backup anteriores
Write-Host ""
Write-Host "=== Desinstalando programas de backup anteriores ===" -ForegroundColor Cyan

$programNames = @("Veeam Agent for Microsoft Windows", "SQL Backup Master", "Macrium Reflect Server Edition")

foreach ($programName in $programNames) {
    $program = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq $programName }

    if ($program) {
        Write-Host "Desinstalando '$programName'"
        $program.Uninstall()
        Write-Host "El programa '$programName' se ha desinstalado correctamente." -ForegroundColor Green
    } else {
        Write-Host "No se encontró '$programName' instalado." -ForegroundColor Gray
    }
}

# Ejecutar Reflect Cleaner
Write-Host ""
Write-Host "Iniciando Reflect Cleaner" -ForegroundColor Yellow
Start-Process -Wait -FilePath "$reflectSource\Cleaner-hawk007\Cleaner.exe"

# Instalar Reflect Server Plus
Write-Host ""
Write-Host "=== Instalando Reflect Server Plus ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "gicaf39137@breazeim.com" -ForegroundColor Yellow
Write-Host "QV7E-NR27" -ForegroundColor Yellow
Write-Host ""

Write-Host "Iniciando Instalador de Reflect"
Start-Process -Wait -FilePath "$reflectSource\reflect_server_plus_setup_x64.exe"
Stop-Service -Name "MacriumService"

# Aplicar Patch
Write-Host "Iniciando Patch de Reflect" -ForegroundColor Yellow
Start-Process -Wait -FilePath "$reflectSource\Patch\Macrium_Reflect-7.x_8.x-patch.exe"

# Copiar plantillas de configuración
Write-Host ""
Write-Host "=== Configurando plantillas de Reflect ===" -ForegroundColor Cyan

Copy-Item -Path "$toolsPath\Reflect\Reflect" -Destination "$user_profile\Documents" -Recurse -Force

# Personalizar archivos XML y registro con datos del cliente
(Get-Content -Path "$user_profile\Documents\Reflect\My Backup.xml") | ForEach-Object { $_ -replace "NIT-", "$client_code-" } | Set-Content -Path "$user_profile\Documents\Reflect\My Backup.xml"
(Get-Content -Path "$user_profile\Documents\Reflect\My Backup.xml") | ForEach-Object { $_ -replace "nites", "$client_string" } | Set-Content -Path "$user_profile\Documents\Reflect\My Backup.xml"
(Get-Content -Path "$user_profile\Documents\Reflect\Settings.reg") | ForEach-Object { $_ -replace "candy", "$client_string" } | Set-Content -Path "$user_profile\Documents\Reflect\Settings.reg"

reg.exe import "$user_profile\Documents\Reflect\Settings.reg"

(Get-Content -Path "$user_profile\Documents\Reflect\Files.xml") | ForEach-Object { $_ -replace "NIT-", "$client_code-" } | Set-Content -Path "$user_profile\Documents\Reflect\Files.xml"
(Get-Content -Path "$user_profile\Documents\Reflect\Files.xml") | ForEach-Object { $_ -replace "nites", "$client_string" } | Set-Content -Path "$user_profile\Documents\Reflect\Files.xml"

# Limpiar backups de SQLBM
Write-Host ""
Write-Host "=== Limpiando backups anteriores ===" -ForegroundColor Cyan

Remove-Item -Path "\\172.21.15.130\$client_string\SQLBAK\*" -Recurse -Force -ErrorAction SilentlyContinue

# Mover archivos de imagen existentes
$sourceFolderPath = "\\172.21.15.130\$client_string"
$destinationFolderPath = "\\172.21.15.130\$client_string\IMAGE"

if (-not (Test-Path $destinationFolderPath)) {
    New-Item -ItemType Directory -Path $destinationFolderPath | Out-Null
    Write-Host "Se ha creado la carpeta $destinationFolderPath" -ForegroundColor Green
} else {
    Write-Host "La carpeta $destinationFolderPath ya existe" -ForegroundColor Gray
}

$files = Get-ChildItem -Path $sourceFolderPath -Filter "*.mrimg" -ErrorAction SilentlyContinue

foreach ($file in $files) {
    Move-Item -Path $file.FullName -Destination $destinationFolderPath
    Write-Host "Se movió el archivo $($file.Name) al destino."
}

# Eliminar tareas programadas anteriores
Write-Host ""
Write-Host "=== Eliminando tareas programadas anteriores ===" -ForegroundColor Cyan

$nombreTareas = @("Reflect", "SQL Full", "SQL Log", "Reflect Image", "Reflect Files", "Veeam")

foreach ($nombreTarea in $nombreTareas) {
    $task = Get-ScheduledTask -TaskName $nombreTarea -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $nombreTarea -Confirm:$false
        Write-Host "Tarea '$nombreTarea' eliminada." -ForegroundColor Green
    }
}

# # Agregar nuevas tareas programadas

# Write-Host "Agregar tareas programadas."

# $documentsPath = [Environment]::GetFolderPath("MyDocuments")

# $xmlPath = '-e -w -inc "' + $documentsPath + '\Reflect\My Backup.xml"'
# Register-ScheduledTask `
#     -TaskName "Reflect Image" `
#     -Action (New-ScheduledTaskAction -Execute "C:\Program Files\Macrium\Reflect\Reflect.exe" -Argument $xmlPath) `
#     -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "00:00" -RandomDelay (New-TimeSpan -Hours 8)) `
#     -Principal (New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount) `
#     -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable)

# $xmlPath = '-e -w -inc "' + $documentsPath + '\Reflect\Files.xml"'
# Register-ScheduledTask `
#     -TaskName "Reflect Files" `
#     -Action (New-ScheduledTaskAction -Execute "C:\Program Files\Macrium\Reflect\Reflect.exe" -Argument $xmlPath) `
#     -Trigger (New-ScheduledTaskTrigger -Daily -At "00:00" -RandomDelay (New-TimeSpan -Hours 8)) `
#     -Principal (New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount) `
#     -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable)

# Reactivar antivirus
if ($osVersion -notmatch 'Windows Server 2012') {
    Write-Host ""
    Write-Host "Activando antivirus" -ForegroundColor Yellow
    Set-MpPreference -DisableRealtimeMonitoring $false
}

Write-Host ""
Write-Host "=== Instalación de Backup completada ===" -ForegroundColor Green
