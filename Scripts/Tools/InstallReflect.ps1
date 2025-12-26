Import-Module ScheduledTasks
Set-Location $PSScriptRoot

$user_profile = $env:USERPROFILE
$osVersion = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'ProductName').ProductName

if ($osVersion -notmatch 'Windows Server 2012') {
    Write-Host "Desactivando antivirus"
    Set-MpPreference -DisableRealtimeMonitoring $true
}


# Ingresar variables del cliente
$client_code = "";
$client_string = "";

while (-not ($client_code -match "^[A-Z]{3}$")) {
    $client_code = Read-Host "Ingresa el código del cliente:"
}

while (-not ($client_string -cmatch "^[a-z]+$")) {
    $client_string = Read-Host "Ingresa el nombre de carpeta del cliente:"
}

# Desinstalar programas
$programNames = @("Veeam Agent for Microsoft Windows", "SQL Backup Master", "Macrium Reflect Server Edition")

foreach ($programName in $programNames) {
    $program = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq $programName }

    if ($program) {
        Write-Host "Desinstalando '$programName'"
        $program.Uninstall()
        Write-Host "El programa '$programName' se ha desinstalado correctamente."
    } else {
        Write-Host "No se encontró el programa '$programName' instalado en el sistema."
    }
}

Write-Host "Iniciando Reflect Cleaner"
Start-Process -Wait -FilePath "Reflect\Macrium Reflect 8.0.5946 x64 incl Keygen [CrackingPatching]\Cleaner-hawk007\Cleaner.exe"

Write-Host ""
Write-Host "Instalando Reflect Server Plus"
Write-Host ""
Write-Host "gicaf39137@breazeim.com"
Write-Host "QV7E-NR27"
Write-Host ""

Write-Host "Iniciando Instalador de Reflect"
Start-Process -Wait -FilePath "Reflect\Macrium Reflect 8.0.5946 x64 incl Keygen [CrackingPatching]\reflect_server_plus_setup_x64.exe" 
Stop-Service -Name "MacriumService"

Write-Host "Iniciando Patch de Reflect"
Start-Process -Wait -FilePath "Reflect\Macrium Reflect 8.0.5946 x64 incl Keygen [CrackingPatching]\Patch\Macrium_Reflect-7.x_8.x-patch.exe"

Copy-Item -Path "Reflect\Reflect" -Destination "$user_profile\Documents" -Recurse -Force

(Get-Content -Path "$user_profile\Documents\Reflect\My Backup.xml") | ForEach-Object { $_ -replace "NIT-", "$client_code-" } | Set-Content -Path "$user_profile\Documents\Reflect\My Backup.xml"
(Get-Content -Path "$user_profile\Documents\Reflect\My Backup.xml") | ForEach-Object { $_ -replace "nites", "$client_string" } | Set-Content -Path "$user_profile\Documents\Reflect\My Backup.xml"
(Get-Content -Path "$user_profile\Documents\Reflect\Settings.reg") | ForEach-Object { $_ -replace "candy", "$client_string" } | Set-Content -Path "$user_profile\Documents\Reflect\Settings.reg"

reg.exe import "$user_profile\Documents\Reflect\Settings.reg"

(Get-Content -Path "$user_profile\Documents\Reflect\Files.xml") | ForEach-Object { $_ -replace "NIT-", "$client_code-" } | Set-Content -Path "$user_profile\Documents\Reflect\Files.xml"
(Get-Content -Path "$user_profile\Documents\Reflect\Files.xml") | ForEach-Object { $_ -replace "nites", "$client_string" } | Set-Content -Path "$user_profile\Documents\Reflect\Files.xml"

# Eliminar backups de SQLBM
Remove-Item -Path "\\172.21.15.130\$client_string\SQLBAK\*" -Recurse -Force

# Mover archivos de imagen
$sourceFolderPath = "\\172.21.15.130\$client_string"
$destinationFolderPath = "\\172.21.15.130\$client_string\IMAGE"

if (-not (Test-Path $destinationFolderPath)) {
    New-Item -ItemType Directory -Path $destinationFolderPath | Out-Null
    Write-Host "Se ha creado la carpeta $destinationFolderPath"
} else {
    Write-Host "La carpeta $destinationFolderPath ya existe"
}

$files = Get-ChildItem -Path $sourceFolderPath -Filter "*.mrimg"

foreach ($file in $files) {
    Move-Item -Path $file.FullName -Destination $destinationFolderPath
    Write-Host "Se movió el archivo $($file.Name) al destino."
}

# Eliminar tareas programadas
$nombreTareas = @("Reflect", "SQL Full", "SQL Log", "Reflect Image", "Reflect Files", "Veeam")

foreach ($nombreTarea in $nombreTareas) {
    Get-ScheduledTask -TaskName $nombreTarea | Unregister-ScheduledTask -Confirm:$false
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

if ($osVersion -notmatch 'Windows Server 2012') {
    Write-Host "Activando antivirus"
    Set-MpPreference -DisableRealtimeMonitoring $false
}
    
do {
    # Consulta al usuario si desea reiniciar el equipo
    $confirm = Read-Host "¿Desea reiniciar el equipo? (S/N)"

    # Verifica la entrada del usuario y reinicia el equipo si se ingresa "S"
    if ($confirm -ieq "S") {
        Write-Host "Reiniciando el equipo..."
        Restart-Computer -Force
        break
    } elseif ($confirm -ieq "N") {
        Write-Host "No se reiniciará el equipo."
        break
    } else {
        Write-Host "Opción no válida. Por favor, ingrese 'S' o 'N'."
    }
} while ($true)

