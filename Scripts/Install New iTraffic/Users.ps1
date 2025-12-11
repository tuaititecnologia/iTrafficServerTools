enerar contraseñas seguras
$Password1 = Generate-UserPassword
$Password2 = Generate-UserPassword

# Función para crear o actualizar un usuario
function Ensure-User {
    param (
        [string]$Username,
        [string]$Password
    )

    if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
        Write-Host "El usuario $Username ya existe. Actualizando contraseña..."
        $securePass = ConvertTo-SecureString -AsPlainText $Password -Force
        Set-LocalUser -Name $Username -Password $securePass
    } else {
        Write-Host "Creando usuario $Username..."
        New-LocalUser -Name $Username -Password (ConvertTo-SecureString -AsPlainText $Password -Force) -UserMayNotChangePassword -AccountNeverExpires
    }

    # Asegurar que esté en Administradores
    if (-not (Get-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction SilentlyContinue)) {
        Add-LocalGroupMember -Group "Administrators" -Member $Username
    }
}

# Aplicar a ambos usuarios
Ensure-User -Username "softur" -Password $Password1
Ensure-User -Username "softur2" -Password $Password2

# Guardar contraseñas en el escritorio
$desktopPath = [Environment]::GetFolderPath("Desktop")
@"
Usuario: softur
Contraseña: $Password1

Usuario: softur2
Contraseña: $Password2
"@ | Set-Content -Path "$desktopPath\\usuarios-softur.txt" -Encoding UTF8

Write-Host "Usuarios configurados y contraseñas actualizadas en el escritorio."