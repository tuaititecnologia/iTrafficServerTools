# ============================================================================
# Script de Configuración de Credenciales para Archivo de Bases de Datos
# ============================================================================
# Este script solicita y guarda las credenciales de acceso al NAS
# donde se almacenarán los archivos comprimidos de las bases de datos.
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
# Configuración
# ============================================================================
$credentialsXmlPath = Join-Path $PSScriptRoot "ArchiveCredentials.xml"
$defaultNasPath = "\\10.69.88.82\Backups\ARCHIVE\SQLDATA"

Write-Host ""
Write-Host "=== Configuración de Credenciales para Archivo de Bases de Datos ===" -ForegroundColor Cyan
Write-Host ""

# Verificar si ya existen credenciales
$credentialsExist = Test-Path $credentialsXmlPath
if ($credentialsExist) {
    Write-Host "Ya existe un archivo de credenciales en:" -ForegroundColor Yellow
    Write-Host "  $credentialsXmlPath" -ForegroundColor Gray
    Write-Host ""
    $overwrite = Read-Host "¿Desea sobrescribir las credenciales existentes? (S/N)"
    if ($overwrite.Trim().ToUpper() -notin @("S", "SI", "Y", "YES")) {
        Write-Host ""
        Write-Host "Operación cancelada." -ForegroundColor Yellow
        pause
        exit 0
    }
    Write-Host ""
}

# Solicitar información
Write-Host "Ingrese la información de acceso al NAS:" -ForegroundColor Cyan
Write-Host ""

# Ruta del NAS
Write-Host "Ruta del share del NAS:" -ForegroundColor White
Write-Host "  (Presione Enter para usar: $defaultNasPath)" -ForegroundColor Gray
$nasPath = Read-Host "Ruta"
if ([string]::IsNullOrWhiteSpace($nasPath)) {
    $nasPath = $defaultNasPath
}
$nasPath = $nasPath.Trim()

# Validar formato de ruta UNC
if (-not $nasPath.StartsWith("\\")) {
    Write-Host ""
    Write-Host "Error: La ruta debe ser una ruta UNC (debe comenzar con \\)" -ForegroundColor Red
    Write-Host "Ejemplo: \\10.69.88.82\Backups\ARCHIVE\SQLDATA" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host ""

# Usuario
Write-Host "Usuario del dominio:" -ForegroundColor White
Write-Host "  (Formato: DOMINIO\Usuario o Usuario@dominio.com)" -ForegroundColor Gray
$username = Read-Host "Usuario"
if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host ""
    Write-Host "Error: Debe ingresar un usuario." -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}
$username = $username.Trim()

Write-Host ""

# Contraseña
Write-Host "Contraseña:" -ForegroundColor White
$securePassword = Read-Host "Contraseña" -AsSecureString
if ($securePassword.Length -eq 0) {
    Write-Host ""
    Write-Host "Error: Debe ingresar una contraseña." -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

# Crear objeto de credenciales
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

Write-Host ""
Write-Host "Validando credenciales..." -ForegroundColor Yellow

# Validar credenciales intentando conectar al share
try {
    # Intentar mapear temporalmente el share
    $tempDrive = "Z"
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq $tempDrive }
    if ($drives) {
        # Si la unidad Z ya existe, usar otra
        $tempDrive = "Y"
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq $tempDrive }
        if ($drives) {
            $tempDrive = "X"
        }
    }
    
    $mapped = $false
    try {
        # Intentar mapear el share con las credenciales
        $null = New-PSDrive -Name $tempDrive -PSProvider FileSystem -Root $nasPath -Credential $credential -ErrorAction Stop
        $mapped = $true
        
        # Verificar que se puede acceder
        $testPath = "$tempDrive`:\"
        if (Test-Path $testPath) {
            # Intentar crear un archivo de prueba para verificar permisos de escritura
            $testFile = Join-Path $testPath ".test_write_permission_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
            try {
                $null = New-Item -Path $testFile -ItemType File -Force -ErrorAction Stop
                Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                Write-Host "  Credenciales válidas y permisos de escritura confirmados." -ForegroundColor Green
            } catch {
                Write-Host ""
                Write-Host "Advertencia: Las credenciales son válidas pero no se pudo verificar permisos de escritura." -ForegroundColor Yellow
                Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
                Write-Host ""
                $continue = Read-Host "¿Desea continuar de todas formas? (S/N)"
                if ($continue.Trim().ToUpper() -notin @("S", "SI", "Y", "YES")) {
                    Remove-PSDrive -Name $tempDrive -Force -ErrorAction SilentlyContinue
                    Write-Host ""
                    Write-Host "Operación cancelada." -ForegroundColor Yellow
                    pause
                    exit 0
                }
            }
        } else {
            throw "No se pudo acceder al share"
        }
    } catch {
        Write-Host ""
        Write-Host "Error: No se pudo conectar al share con las credenciales proporcionadas." -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Por favor, verifique:" -ForegroundColor Yellow
        Write-Host "  - La ruta del share es correcta" -ForegroundColor Yellow
        Write-Host "  - El usuario y contraseña son correctos" -ForegroundColor Yellow
        Write-Host "  - El servidor NAS está accesible desde esta máquina" -ForegroundColor Yellow
        Write-Host ""
        pause
        exit 1
    } finally {
        if ($mapped) {
            Remove-PSDrive -Name $tempDrive -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Host ""
    Write-Host "Error inesperado durante la validación: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

# Guardar credenciales en XML cifrado
Write-Host ""
Write-Host "Guardando credenciales cifradas..." -ForegroundColor Yellow

try {
    $config = @{
        NasPath = $nasPath
        Credential = $credential
    }
    
    $config | Export-Clixml -Path $credentialsXmlPath -Force
    
    Write-Host "  Credenciales guardadas exitosamente en:" -ForegroundColor Green
    Write-Host "  $credentialsXmlPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Nota: Las credenciales están cifradas usando DPAPI de Windows." -ForegroundColor Cyan
    Write-Host "      Solo pueden descifrarse en esta misma máquina y con el mismo usuario." -ForegroundColor Cyan
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "Error al guardar las credenciales: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

Write-Host "=== Configuración Completada ===" -ForegroundColor Cyan
Write-Host ""
pause
