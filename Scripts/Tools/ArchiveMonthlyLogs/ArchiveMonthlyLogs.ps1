# ============================================================================
# Script de Archivo Mensual de Bases de Datos de Logs Particionadas
# ============================================================================
# Este script automatiza el proceso mensual de archivo de bases de datos
# de logs de iTraffic que siguen el patrón iTraffic_EurovipsLogsYYYYMM.
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
    exit 1
}

# ============================================================================
# Configuración
# ============================================================================
$SqlServerInstance = "localhost"  # Configurar según necesidad: "SERVERNAME" o "SERVERNAME\INSTANCE"
$SqlDataPath = "G:\SQLDATA"
$NasArchivePath = "\\10.69.88.82\Backups\ARCHIVE\SQLDATA"
# Archivo de credenciales en ubicación persistente (fuera de la carpeta del script)
$credentialsFolder = Join-Path $env:ProgramData "iTrafficServerTools"
if (-not (Test-Path $credentialsFolder)) {
    $null = New-Item -Path $credentialsFolder -ItemType Directory -Force
}
$CredentialsXmlPath = Join-Path $credentialsFolder "ArchiveCredentials.xml"
$RetentionMonths = 3  # Archivar bases más antiguas que este número de meses
$DatabaseNamePattern = "iTraffic_EurovipsLogs"

# Ruta del ejecutable de 7-Zip (ajustar según instalación si está en otra ubicación)
$SevenZipPath = Join-Path $env:ProgramFiles "7-Zip\7z.exe"

# ============================================================================
# Cargar librerías comunes
# ============================================================================
if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "Error: No se encontró la utilidad sqlcmd." -ForegroundColor Red
    Write-Host "Instale SQL Server Command Line Utilities o el Feature Pack." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$commonLibraryPath = Join-Path (Split-Path $PSScriptRoot -Parent) "CommonSqlServerUtils.ps1"
if (-not (Test-Path $commonLibraryPath)) {
    Write-Host ""
    Write-Host "Error: No se encontró la librería requerida: $commonLibraryPath" -ForegroundColor Red
    Write-Host ""
    exit 1
}

. $commonLibraryPath

# ============================================================================
# Funciones
# ============================================================================

function Get-LogDatabases {
    param(
        [string]$ServerInstance,
        [string]$Pattern
    )
    
    $query = @"
SET NOCOUNT ON;
SELECT name, database_id, state_desc
FROM sys.databases
WHERE name LIKE '$Pattern%'
ORDER BY name;
"@
    
    try {
        $output = Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query
        $databases = @()
        
        foreach ($line in $output) {
            if (-not $line) { continue }
            $trimmed = $line.Trim()
            if ($trimmed -eq "" -or $trimmed -match "^\(.* rows affected\)$") { continue }
            
            $parts = $line -split "\|"
            if ($parts.Count -ge 3) {
                $dbName = $parts[0].Trim()
                $state = $parts[2].Trim()
                
                # Solo procesar bases de datos online
                if ($dbName -and $state -eq "ONLINE") {
                    # Extraer fecha del nombre (formato: PatternYYYYMM)
                    if ($dbName -match "${Pattern}(\d{6})$") {
                        $dateStr = $matches[1]
                        try {
                            $year = [int]$dateStr.Substring(0, 4)
                            $month = [int]$dateStr.Substring(4, 2)
                            $date = Get-Date -Year $year -Month $month -Day 1
                            
                            $databases += [PSCustomObject]@{
                                Name = $dbName
                                Date = $date
                                YearMonth = $dateStr
                            }
                        } catch {
                            # Ignorar bases de datos que no coincidan con el formato
                            continue
                        }
                    }
                }
            }
        }
        
        return $databases | Sort-Object Date
    } catch {
        Write-Host "Error obteniendo bases de datos: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Get-DatabasePhysicalFiles {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName
    )
    
    $query = @"
SET NOCOUNT ON;
SELECT 
    name AS LogicalFileName,
    type_desc AS FileType,
    physical_name AS PhysicalPath
FROM sys.master_files
WHERE database_id = DB_ID('$DatabaseName')
AND type_desc IN ('ROWS', 'LOG')
ORDER BY type_desc;
"@
    
    try {
        $output = Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query
        $files = @{
            MDF = @()
            LDF = @()
        }
        
        foreach ($line in $output) {
            if (-not $line) { continue }
            $trimmed = $line.Trim()
            if ($trimmed -eq "" -or $trimmed -match "^\(.* rows affected\)$") { continue }
            
            $parts = $line -split "\|"
            if ($parts.Count -ge 3) {
                $fileType = $parts[1].Trim()
                $physicalPath = $parts[2].Trim()
                
                if ($fileType -eq "ROWS") {
                    $files.MDF += $physicalPath
                } elseif ($fileType -eq "LOG") {
                    $files.LDF += $physicalPath
                }
            }
        }
        
        return $files
    } catch {
        Write-Host "Error obteniendo archivos físicos: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Invoke-DetachDatabase {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName
    )
    
    Write-Host "  Desacoplando base de datos..." -ForegroundColor Yellow
    
    try {
        # Poner la base de datos en modo single user y desconectar todas las conexiones
        $query1 = @"
ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
"@
        Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query1 | Out-Null
        
        # Detach de la base de datos
        $escapedName = $DatabaseName.Replace("'", "''")
        $query2 = @"
EXEC sp_detach_db @dbname = '$escapedName';
"@
        Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query2 | Out-Null
        
        Write-Host "  Base de datos desacoplada exitosamente." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  Error al desacoplar la base de datos: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Invoke-CompressDatabaseFiles {
    param(
        [string[]]$MdfFiles,
        [string[]]$LdfFiles,
        [string]$OutputZipPath,
        [string]$SevenZipExecutable
    )
    
    Write-Host "  Comprimiendo archivos..." -ForegroundColor Yellow
    
    try {
        # Verificar que 7-Zip existe
        if (-not (Test-Path $SevenZipExecutable)) {
            throw "No se encontró el ejecutable de 7-Zip en: $SevenZipExecutable"
        }
        
        $allFiles = @()
        $allFiles += $MdfFiles
        $allFiles += $LdfFiles
        
        # Verificar que todos los archivos existan
        foreach ($file in $allFiles) {
            if (-not (Test-Path $file)) {
                throw "Archivo no encontrado: $file"
            }
        }
        
        # Eliminar ZIP existente si existe
        if (Test-Path $OutputZipPath) {
            Remove-Item $OutputZipPath -Force -ErrorAction SilentlyContinue
        }
        
        # Usar 7-Zip con compresión mínima (Store = 0, Fastest = 1)
        # -mx=1 es compresión rápida (mínima)
        # -tzip crea un archivo ZIP
        $arguments = @(
            "a",                    # Agregar archivos
            "-tzip",                # Tipo: ZIP
            "-mx=1",                # Nivel de compresión: 1 (Fastest/Mínima)
            "`"$OutputZipPath`""   # Archivo de salida
        )
        
        # Agregar cada archivo como argumento separado
        foreach ($file in $allFiles) {
            $arguments += "`"$file`""
        }
        
        Write-Host "  Ejecutando 7-Zip..." -ForegroundColor Gray
        $process = Start-Process -FilePath $SevenZipExecutable -ArgumentList $arguments -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -ne 0) {
            throw "7-Zip falló con código de salida: $($process.ExitCode)"
        }
        
        # Verificar que el archivo ZIP se creó
        if (-not (Test-Path $OutputZipPath)) {
            throw "El archivo ZIP no se creó correctamente"
        }
        
        Write-Host "  Archivos comprimidos exitosamente." -ForegroundColor Green
        Write-Host "  Archivo ZIP: $OutputZipPath" -ForegroundColor Gray
        
        $zipSize = (Get-Item $OutputZipPath).Length
        $zipSizeMB = [math]::Round($zipSize / 1MB, 2)
        Write-Host "  Tamaño del ZIP: $zipSizeMB MB" -ForegroundColor Gray
        
        return $true
    } catch {
        Write-Host "  Error al comprimir archivos: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Test-ZipIntegrity {
    param(
        [string]$ZipPath,
        [string]$SevenZipExecutable
    )
    
    Write-Host "  Verificando integridad del ZIP..." -ForegroundColor Yellow
    
    try {
        if (-not (Test-Path $ZipPath)) {
            throw "El archivo ZIP no existe: $ZipPath"
        }
        
        # Verificar que el archivo tenga contenido
        $zipFile = Get-Item $ZipPath
        if ($zipFile.Length -eq 0) {
            throw "El archivo ZIP está vacío"
        }
        
        # Verificar que 7-Zip existe
        if (-not (Test-Path $SevenZipExecutable)) {
            throw "No se encontró el ejecutable de 7-Zip en: $SevenZipExecutable"
        }
        
        # Usar 7-Zip para verificar integridad (test)
        # 7-Zip test verifica el archivo sin extraerlo
        $arguments = @(
            "t",                    # Test (verificar integridad)
            "`"$ZipPath`""         # Archivo a verificar
        )
        
        $process = Start-Process -FilePath $SevenZipExecutable -ArgumentList $arguments -Wait -NoNewWindow -PassThru -RedirectStandardOutput $null -RedirectStandardError $null
        
        if ($process.ExitCode -ne 0) {
            throw "El archivo ZIP está corrupto o no es válido (código de salida: $($process.ExitCode))"
        }
        
        # También verificar que contiene archivos listando el contenido
        $arguments = @(
            "l",                    # List (listar contenido)
            "`"$ZipPath`""         # Archivo a listar
        )
        
        $listOutput = & $SevenZipExecutable $arguments 2>&1
        $fileCount = ($listOutput | Select-String -Pattern "^\s+\d+\s+\d+\s+\d+\s+\d{4}-\d{2}-\d{2}" | Measure-Object).Count
        
        if ($fileCount -eq 0) {
            throw "El ZIP está vacío o no se pudo leer su contenido"
        }
        
        Write-Host "  Integridad del ZIP verificada. Archivos encontrados: $fileCount" -ForegroundColor Green
        
        return $true
    } catch {
        Write-Host "  Error al verificar integridad del ZIP: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Copy-ToNAS {
    param(
        [string]$ZipPath,
        [string]$NasPath,
        [string]$CredentialsXmlPath
    )
    
    Write-Host "  Copiando archivo al NAS..." -ForegroundColor Yellow
    
    # Verificar que existe el archivo de credenciales
    if (-not (Test-Path $CredentialsXmlPath)) {
        throw "No se encontró el archivo de credenciales: $CredentialsXmlPath. Ejecute ConfigureArchiveCredentials.ps1 primero."
    }
    
    # Cargar credenciales
    try {
        $config = Import-Clixml -Path $CredentialsXmlPath
        $credential = $config.Credential
        $configNasPath = $config.NasPath
        
        # Usar la ruta del NAS de la configuración si está disponible
        if ($configNasPath) {
            $NasPath = $configNasPath
        }
    } catch {
        throw "Error al cargar credenciales: $($_.Exception.Message)"
    }
    
    # Mapear el share del NAS
    $tempDrive = "Z"
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq $tempDrive }
    if ($drives) {
        $tempDrive = "Y"
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq $tempDrive }
        if ($drives) {
            $tempDrive = "X"
        }
    }
    
    $mapped = $false
    try {
        # Mapear el share
        Write-Host "  Conectando al NAS..." -ForegroundColor Gray
        $null = New-PSDrive -Name $tempDrive -PSProvider FileSystem -Root $NasPath -Credential $credential -ErrorAction Stop
        $mapped = $true
        
        # Verificar conectividad
        $nasRoot = "$tempDrive`:\"
        if (-not (Test-Path $nasRoot)) {
            throw "No se pudo acceder al share del NAS"
        }
        
        Write-Host "  Conectado al NAS exitosamente." -ForegroundColor Green
        
        # Copiar el archivo
        $zipFileName = Split-Path $ZipPath -Leaf
        $nasDestination = Join-Path $nasRoot $zipFileName
        
        Write-Host "  Copiando $zipFileName al NAS..." -ForegroundColor Gray
        Copy-Item -Path $ZipPath -Destination $nasDestination -Force -ErrorAction Stop
        
        # Verificar que la copia fue exitosa comparando tamaños
        $localSize = (Get-Item $ZipPath).Length
        $nasSize = (Get-Item $nasDestination).Length
        
        if ($localSize -ne $nasSize) {
            throw "Los tamaños de los archivos no coinciden. Local: $localSize bytes, NAS: $nasSize bytes"
        }
        
        Write-Host "  Archivo copiado exitosamente al NAS." -ForegroundColor Green
        Write-Host "  Destino: $nasDestination" -ForegroundColor Gray
        Write-Host "  Tamaño: $([math]::Round($nasSize / 1MB, 2)) MB" -ForegroundColor Gray
        
        return $true
    } catch {
        Write-Host "  Error al copiar al NAS: $($_.Exception.Message)" -ForegroundColor Red
        throw
    } finally {
        if ($mapped) {
            Remove-PSDrive -Name $tempDrive -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-CreateNewLogDatabase {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName,
        [string]$SqlDataPath
    )
    
    Write-Host "  Creando nueva base de datos..." -ForegroundColor Yellow
    
    try {
        # Generar nombres de archivos
        $mdfPath = Join-Path $SqlDataPath "$DatabaseName.mdf"
        $ldfPath = Join-Path $SqlDataPath "$DatabaseName`_log.ldf"
        
        # Verificar que no existan los archivos
        if (Test-Path $mdfPath) {
            throw "El archivo MDF ya existe: $mdfPath"
        }
        if (Test-Path $ldfPath) {
            throw "El archivo LDF ya existe: $ldfPath"
        }
        
        # Crear la base de datos
        $escapedName = $DatabaseName.Replace("'", "''")
        $escapedMdfPath = $mdfPath.Replace("'", "''")
        $escapedLdfPath = $ldfPath.Replace("'", "''")
        
        $query = @"
CREATE DATABASE [$escapedName]
ON (NAME = '$escapedName', FILENAME = '$escapedMdfPath')
LOG ON (NAME = '${escapedName}_log', FILENAME = '$escapedLdfPath');
"@
        
        Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query | Out-Null
        
        Write-Host "  Base de datos creada exitosamente." -ForegroundColor Green
        Write-Host "  Nombre: $DatabaseName" -ForegroundColor Gray
        Write-Host "  MDF: $mdfPath" -ForegroundColor Gray
        Write-Host "  LDF: $ldfPath" -ForegroundColor Gray
        
        return $true
    } catch {
        Write-Host "  Error al crear la base de datos: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ============================================================================
# Script Principal
# ============================================================================

Write-Host ""
Write-Host "=== Script de Archivo Mensual de Bases de Datos de Logs ===" -ForegroundColor Cyan
Write-Host ""

# Validar configuración
Write-Host "Validando configuración..." -ForegroundColor Yellow

# Verificar archivo de credenciales
if (-not (Test-Path $CredentialsXmlPath)) {
    Write-Host ""
    Write-Host "Error: No se encontró el archivo de credenciales." -ForegroundColor Red
    Write-Host "  Ruta esperada: $CredentialsXmlPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Por favor, ejecute primero:" -ForegroundColor Yellow
    Write-Host "  .\ConfigureArchiveCredentials.ps1" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Verificar ruta de datos SQL
if (-not (Test-Path $SqlDataPath)) {
    Write-Host ""
    Write-Host "Error: La ruta de datos SQL no existe: $SqlDataPath" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# Verificar que 7-Zip existe
if (-not (Test-Path $SevenZipPath)) {
    Write-Host ""
    Write-Host "Error: No se encontró el ejecutable de 7-Zip." -ForegroundColor Red
    Write-Host "  Ruta esperada: $SevenZipPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Por favor, ajuste la variable `$SevenZipPath en el script o instale 7-Zip." -ForegroundColor Yellow
    Write-Host "Rutas comunes:" -ForegroundColor Yellow
    Write-Host "  $env:ProgramFiles\7-Zip\7z.exe" -ForegroundColor Gray
    Write-Host "  $env:ProgramFiles(x86)\7-Zip\7z.exe" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "  Configuración válida." -ForegroundColor Green
Write-Host "  7-Zip encontrado: $SevenZipPath" -ForegroundColor Gray
Write-Host ""

# Obtener bases de datos de logs
Write-Host "Buscando bases de datos de logs..." -ForegroundColor Yellow
try {
    $logDatabases = Get-LogDatabases -ServerInstance $SqlServerInstance -Pattern $DatabaseNamePattern
} catch {
    Write-Host ""
    Write-Host "Error: No se pudieron obtener las bases de datos." -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if ($logDatabases.Count -eq 0) {
    Write-Host ""
    Write-Host "No se encontraron bases de datos con el patrón '$DatabaseNamePattern*'" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host "  Bases de datos encontradas: $($logDatabases.Count)" -ForegroundColor Green
Write-Host ""

# Verificar retención
$now = Get-Date
$cutoffDate = $now.AddMonths(-$RetentionMonths)

Write-Host "Criterio de retención: Archivar bases más antiguas que $RetentionMonths meses" -ForegroundColor Cyan
Write-Host "  Fecha de corte: $($cutoffDate.ToString('yyyy-MM'))" -ForegroundColor Gray
Write-Host ""

# Filtrar bases de datos que cumplen el criterio de retención
$databasesToArchive = $logDatabases | Where-Object { $_.Date -lt $cutoffDate }

if ($databasesToArchive.Count -eq 0) {
    Write-Host "No hay bases de datos que requieran archivo." -ForegroundColor Green
    Write-Host "Todas las bases de datos están dentro del período de retención." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Seleccionar la base de datos más antigua
$oldestDatabase = $databasesToArchive | Select-Object -First 1

Write-Host "Base de datos seleccionada para archivo:" -ForegroundColor Cyan
Write-Host "  Nombre: $($oldestDatabase.Name)" -ForegroundColor White
Write-Host "  Fecha: $($oldestDatabase.Date.ToString('yyyy-MM'))" -ForegroundColor White
Write-Host "  Antigüedad: $([math]::Round(($now - $oldestDatabase.Date).TotalDays / 30, 1)) meses" -ForegroundColor White
Write-Host ""

# Obtener archivos físicos
Write-Host "Obteniendo información de archivos físicos..." -ForegroundColor Yellow
try {
    $physicalFiles = Get-DatabasePhysicalFiles -ServerInstance $SqlServerInstance -DatabaseName $oldestDatabase.Name
} catch {
    Write-Host ""
    Write-Host "Error: No se pudieron obtener los archivos físicos." -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if ($physicalFiles.MDF.Count -eq 0 -or $physicalFiles.LDF.Count -eq 0) {
    Write-Host ""
    Write-Host "Error: No se encontraron archivos MDF o LDF para la base de datos." -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host "  Archivos encontrados:" -ForegroundColor Green
foreach ($mdf in $physicalFiles.MDF) {
    Write-Host "    MDF: $mdf" -ForegroundColor Gray
}
foreach ($ldf in $physicalFiles.LDF) {
    Write-Host "    LDF: $ldf" -ForegroundColor Gray
}
Write-Host ""

# Calcular espacio que se liberará
$totalSize = 0
foreach ($mdf in $physicalFiles.MDF) {
    if (Test-Path $mdf) {
        $totalSize += (Get-Item $mdf).Length
    }
}
foreach ($ldf in $physicalFiles.LDF) {
    if (Test-Path $ldf) {
        $totalSize += (Get-Item $ldf).Length
    }
}
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "Espacio que se liberará: $totalSizeMB MB" -ForegroundColor Cyan
Write-Host ""

# Proceso de archivo
Write-Host "=== Iniciando Proceso de Archivo ===" -ForegroundColor Cyan
Write-Host ""

$errorOccurred = $false
$detached = $false

try {
    # 1. Detach de la base de datos
    Write-Host "[1/6] Desacoplando base de datos..." -ForegroundColor Yellow
    Invoke-DetachDatabase -ServerInstance $SqlServerInstance -DatabaseName $oldestDatabase.Name
    $detached = $true
    Write-Host ""
    
    # 2. Comprimir archivos
    Write-Host "[2/6] Comprimiendo archivos..." -ForegroundColor Yellow
    $zipFileName = "$($oldestDatabase.Name).zip"
    $zipPath = Join-Path $env:TEMP $zipFileName
    
    Invoke-CompressDatabaseFiles -MdfFiles $physicalFiles.MDF -LdfFiles $physicalFiles.LDF -OutputZipPath $zipPath -SevenZipExecutable $SevenZipPath
    Write-Host ""
    
    # 3. Verificar integridad del ZIP
    Write-Host "[3/6] Verificando integridad del ZIP..." -ForegroundColor Yellow
    Test-ZipIntegrity -ZipPath $zipPath -SevenZipExecutable $SevenZipPath
    Write-Host ""
    
    # 4. Copiar al NAS
    Write-Host "[4/6] Copiando al NAS..." -ForegroundColor Yellow
    Copy-ToNAS -ZipPath $zipPath -NasPath $NasArchivePath -CredentialsXmlPath $CredentialsXmlPath
    Write-Host ""
    
    # 5. Eliminar archivos locales
    Write-Host "[5/6] Eliminando archivos locales..." -ForegroundColor Yellow
    $filesDeleted = 0
    foreach ($mdf in $physicalFiles.MDF) {
        if (Test-Path $mdf) {
            Remove-Item $mdf -Force -ErrorAction Stop
            Write-Host "  Eliminado: $mdf" -ForegroundColor Gray
            $filesDeleted++
        }
    }
    foreach ($ldf in $physicalFiles.LDF) {
        if (Test-Path $ldf) {
            Remove-Item $ldf -Force -ErrorAction Stop
            Write-Host "  Eliminado: $ldf" -ForegroundColor Gray
            $filesDeleted++
        }
    }
    Write-Host "  Archivos eliminados: $filesDeleted" -ForegroundColor Green
    
    # Eliminar ZIP temporal
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }
    Write-Host ""
    
    # 6. Crear nueva base de datos para el mes siguiente
    Write-Host "[6/6] Creando nueva base de datos..." -ForegroundColor Yellow
    $nextMonth = $now.AddMonths(1)
    $newDatabaseName = "$DatabaseNamePattern$($nextMonth.ToString('yyyyMM'))"
    
    # Verificar que no exista ya
    $existingDbs = Get-LogDatabases -ServerInstance $SqlServerInstance -Pattern $DatabaseNamePattern
    if ($existingDbs | Where-Object { $_.Name -eq $newDatabaseName }) {
        Write-Host "  La base de datos $newDatabaseName ya existe. Omitiendo creación." -ForegroundColor Yellow
    } else {
        Invoke-CreateNewLogDatabase -ServerInstance $SqlServerInstance -DatabaseName $newDatabaseName -SqlDataPath $SqlDataPath
    }
    Write-Host ""
    
    # Resumen
    Write-Host "=== Proceso Completado Exitosamente ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Resumen:" -ForegroundColor Cyan
    Write-Host "  Base de datos archivada: $($oldestDatabase.Name)" -ForegroundColor White
    Write-Host "  Espacio liberado: $totalSizeMB MB" -ForegroundColor White
    Write-Host "  Archivo en NAS: $NasArchivePath\$zipFileName" -ForegroundColor White
    if ($existingDbs | Where-Object { $_.Name -eq $newDatabaseName }) {
        Write-Host "  Nueva base de datos: Ya existía $newDatabaseName" -ForegroundColor White
    } else {
        Write-Host "  Nueva base de datos: $newDatabaseName" -ForegroundColor White
    }
    Write-Host ""
    
    exit 0
    
} catch {
    $errorOccurred = $true
    Write-Host ""
    Write-Host "=== Error Durante el Proceso ===" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    # Rollback: Re-attach de la base de datos si fue desacoplada
    if ($detached) {
        Write-Host "Intentando restaurar la base de datos..." -ForegroundColor Yellow
        try {
            $mdfFile = $physicalFiles.MDF[0]
            if (Test-Path $mdfFile) {
                $escapedName = $oldestDatabase.Name.Replace("'", "''")
                $escapedMdf = $mdfFile.Replace("'", "''")
                $ldfFile = $physicalFiles.LDF[0]
                $escapedLdf = $ldfFile.Replace("'", "''")
                
                $attachQuery = @"
CREATE DATABASE [$escapedName] ON
(FILENAME = '$escapedMdf'),
(FILENAME = '$escapedLdf')
FOR ATTACH;
"@
                Invoke-SqlcmdQuery -ServerInstance $SqlServerInstance -Query $attachQuery | Out-Null
                Write-Host "  Base de datos restaurada exitosamente." -ForegroundColor Green
            } else {
                Write-Host "  No se pudo restaurar: archivos no encontrados." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  Error al restaurar la base de datos: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    exit 1
}
