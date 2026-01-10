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
$RetentionMonths = 2  # Número de meses anteriores al mes actual a mantener (el mes actual siempre se mantiene). Ejemplo: 2 = mantener mes actual + 2 meses anteriores
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
    
    $query = "SET NOCOUNT ON; SELECT name, database_id, state_desc FROM sys.databases WHERE name LIKE '$Pattern%' ORDER BY name;"
    
    try {
        $output = Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query
        $databases = @()
        
        foreach ($line in $output) {
            if (-not $line -or ($line.Trim() -match "^\(.* rows affected\)$")) { continue }
            
            $parts = $line -split "\|"
            if ($parts.Count -ge 3 -and $parts[0].Trim() -and $parts[2].Trim() -eq "ONLINE") {
                $dbName = $parts[0].Trim()
                if ($dbName -match "${Pattern}(\d{6})$") {
                    try {
                        $dateStr = $matches[1]
                        $date = Get-Date -Year ([int]$dateStr.Substring(0, 4)) -Month ([int]$dateStr.Substring(4, 2)) -Day 1
                        $databases += [PSCustomObject]@{ Name = $dbName; Date = $date; YearMonth = $dateStr }
                    } catch { continue }
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
    
    $query = "SET NOCOUNT ON; SELECT name AS LogicalFileName, type_desc AS FileType, physical_name AS PhysicalPath FROM sys.master_files WHERE database_id = DB_ID('$DatabaseName') AND type_desc IN ('ROWS', 'LOG') ORDER BY type_desc;"
    
    try {
        $output = Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query
        $files = @{ MDF = @(); LDF = @() }
        
        foreach ($line in $output) {
            if (-not $line -or ($line.Trim() -match "^\(.* rows affected\)$")) { continue }
            
            $parts = $line -split "\|"
            if ($parts.Count -ge 3) {
                $fileType = $parts[1].Trim()
                $path = $parts[2].Trim()
                if ($fileType -eq "ROWS") { $files.MDF += $path }
                elseif ($fileType -eq "LOG") { $files.LDF += $path }
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
        $escapedName = $DatabaseName.Replace("'", "''")
        Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query "ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;" | Out-Null
        Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query "EXEC sp_detach_db @dbname = '$escapedName';" | Out-Null
        Write-Host "  Base de datos desacoplada exitosamente." -ForegroundColor Green
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
        
        # Verificar archivos y mostrar información
        $totalSize = 0
        Write-Host "  Archivos a comprimir:" -ForegroundColor Gray
        foreach ($file in $allFiles) {
            if (-not (Test-Path $file)) {
                throw "Archivo no encontrado: $file"
            }
            $fileInfo = Get-Item $file
            $totalSize += $fileInfo.Length
            Write-Host "    $($fileInfo.Name) - $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
        }
        Write-Host "  Tamaño total: $([math]::Round($totalSize / 1MB, 2)) MB ($([math]::Round($totalSize / 1GB, 2)) GB)" -ForegroundColor Gray
        
        # Eliminar archivo 7z existente si existe
        if (Test-Path $OutputZipPath) {
            Remove-Item $OutputZipPath -Force -ErrorAction SilentlyContinue
        }
        
        $arguments = @("a", "-t7z", "-mx=1", "-spf2", "`"$OutputZipPath`"")
        foreach ($file in $allFiles) {
            $arguments += "`"$((Resolve-Path $file).Path)`""
        }
        
        Write-Host "  Ejecutando 7-Zip..." -ForegroundColor Gray
        $process = Start-Process -FilePath $SevenZipExecutable -ArgumentList $arguments -WorkingDirectory (Split-Path $SevenZipExecutable -Parent) -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -ne 0) {
            throw "7-Zip falló con código de salida: $($process.ExitCode)"
        }
        
        # Verificar que el archivo 7z se creó
        if (-not (Test-Path $OutputZipPath)) {
            throw "El archivo 7z no se creó correctamente"
        }
        
        $zipSize = (Get-Item $OutputZipPath).Length
        Write-Host "  Archivos comprimidos exitosamente." -ForegroundColor Green
        Write-Host "  Tamaño del archivo: $([math]::Round($zipSize / 1MB, 2)) MB ($([math]::Round($zipSize / 1GB, 2)) GB)" -ForegroundColor Gray
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
    
    Write-Host "  Verificando integridad del archivo 7z..." -ForegroundColor Yellow
    
    try {
        if (-not (Test-Path $ZipPath)) {
            throw "El archivo 7z no existe: $ZipPath"
        }
        
        if ((Get-Item $ZipPath).Length -eq 0) {
            throw "El archivo 7z está vacío"
        }
        
        $nullOutput = [System.IO.Path]::GetTempFileName()
        try {
            $process = Start-Process -FilePath $SevenZipExecutable -ArgumentList @("t", "`"$ZipPath`"") -Wait -NoNewWindow -PassThru -RedirectStandardOutput $nullOutput -RedirectStandardError $nullOutput
            
            if ($process.ExitCode -ne 0) {
                throw "El archivo 7z está corrupto (código: $($process.ExitCode))"
            }
            
            Write-Host "  Integridad del archivo 7z verificada." -ForegroundColor Green
        } finally {
            Remove-Item $nullOutput -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "  Error al verificar integridad del archivo 7z: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Connect-ToNAS {
    param(
        [string]$NasPath,
        [string]$CredentialsXmlPath
    )
    
    if (-not (Test-Path $CredentialsXmlPath)) {
        throw "No se encontró el archivo de credenciales: $CredentialsXmlPath. Ejecute ConfigureArchiveCredentials.ps1 primero."
    }
    
    $config = Import-Clixml -Path $CredentialsXmlPath
    $credential = $config.Credential
    if ($config.NasPath) { $NasPath = $config.NasPath }
    
    $tempDrive = @("Z", "Y", "X") | Where-Object { -not (Get-PSDrive -PSProvider FileSystem -Name $_ -ErrorAction SilentlyContinue) } | Select-Object -First 1
    if (-not $tempDrive) { throw "No hay unidades disponibles para mapear el NAS" }
    
    Write-Host "  Conectando al NAS..." -ForegroundColor Gray
    $null = New-PSDrive -Name $tempDrive -PSProvider FileSystem -Root $NasPath -Credential $credential -ErrorAction Stop
    
    $nasRoot = "$tempDrive`:\"
    if (-not (Test-Path $nasRoot)) {
        Remove-PSDrive -Name $tempDrive -Force -ErrorAction SilentlyContinue
        throw "No se pudo acceder al share del NAS"
    }
    
    Write-Host "  Conectado al NAS exitosamente." -ForegroundColor Green
    
    return @{
        Drive = $tempDrive
        Root = $nasRoot
        Credential = $credential
    }
}

function Get-OrphanedDatabaseFiles {
    param(
        [string]$SqlDataPath,
        [string]$Pattern,
        [array]$ExistingDbNames
    )
    
    Write-Host "Buscando archivos huérfanos (desacoplados)..." -ForegroundColor Yellow
    
    try {
        $orphanedFiles = @()
        
        Get-ChildItem -Path $SqlDataPath -Filter "${Pattern}*.mdf" -File | ForEach-Object {
            $dbName = $_.BaseName
            if ($dbName -match "^${Pattern}(\d{6})$" -and $dbName -notin $ExistingDbNames) {
                $ldfPath = Join-Path $SqlDataPath "${dbName}_log.ldf"
                if (Test-Path $ldfPath) {
                    try {
                        $dateStr = $matches[1]
                        $date = Get-Date -Year ([int]$dateStr.Substring(0, 4)) -Month ([int]$dateStr.Substring(4, 2)) -Day 1
                        $orphanedFiles += [PSCustomObject]@{
                            DatabaseName = $dbName
                            Date = $date
                            YearMonth = $dateStr
                            MdfPath = $_.FullName
                            LdfPath = $ldfPath
                        }
                    } catch { }
                }
            }
        }
        
        return $orphanedFiles | Sort-Object Date
    } catch {
        Write-Host "  Error buscando archivos huérfanos: $($_.Exception.Message)" -ForegroundColor Red
        throw
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
        $mdfPath = Join-Path $SqlDataPath "$DatabaseName.mdf"
        $ldfPath = Join-Path $SqlDataPath "$DatabaseName`_log.ldf"
        
        if (Test-Path $mdfPath -or Test-Path $ldfPath) {
            throw "Los archivos ya existen: $mdfPath o $ldfPath"
        }
        
        $escapedName = $DatabaseName.Replace("'", "''")
        $query = "CREATE DATABASE [$escapedName] ON (NAME = '$escapedName', FILENAME = '$($mdfPath.Replace("'", "''"))') LOG ON (NAME = '${escapedName}_log', FILENAME = '$($ldfPath.Replace("'", "''"))');"
        
        Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query | Out-Null
        
        Write-Host "  Base de datos creada exitosamente: $DatabaseName" -ForegroundColor Green
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

$now = Get-Date
# Retención de N meses: mantener mes actual + N meses anteriores
# Ejemplo: retención de 2 meses = mantener mes actual + 2 meses anteriores (3 meses totales)
# Archivar: todo lo anterior al último mes que se mantiene (mes anterior al último mantenido)
$firstDayOfCurrentMonth = Get-Date -Year $now.Year -Month $now.Month -Day 1
$monthsToKeep = $RetentionMonths + 1
$cutoffYearMonth = [int]$firstDayOfCurrentMonth.AddMonths(-$monthsToKeep).ToString('yyyyMM')
$existingDbNames = $logDatabases | ForEach-Object { $_.Name }

if ($logDatabases.Count -gt 0) {
    Write-Host "  Bases de datos encontradas: $($logDatabases.Count)" -ForegroundColor Green
    Write-Host "Criterio de retención: Mantener $monthsToKeep meses (mes actual + $RetentionMonths meses anteriores)" -ForegroundColor Cyan
    Write-Host "  Se archivan bases <=: $cutoffYearMonth" -ForegroundColor Gray
    Write-Host ""
    $databasesToArchive = $logDatabases | Where-Object { [int]$_.YearMonth -le $cutoffYearMonth }
    Write-Host "  Bases de datos a archivar: $($databasesToArchive.Count)" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "  No se encontraron bases de datos activas con el patrón '$DatabaseNamePattern*'" -ForegroundColor Gray
    Write-Host ""
    $databasesToArchive = @()
}

# Buscar archivos huérfanos (desacoplados pero nunca archivados)
Write-Host ""
$orphanedFiles = Get-OrphanedDatabaseFiles -SqlDataPath $SqlDataPath -Pattern $DatabaseNamePattern -ExistingDbNames $existingDbNames

if ($orphanedFiles.Count -gt 0) {
    Write-Host "  Archivos huérfanos encontrados: $($orphanedFiles.Count)" -ForegroundColor Yellow
    $processOrphaned = $true
    $targetOrphaned = $orphanedFiles | Select-Object -First 1
    $targetFiles = @{ MDF = @($targetOrphaned.MdfPath); LDF = @($targetOrphaned.LdfPath) }
    $targetDatabase = [PSCustomObject]@{ Name = $targetOrphaned.DatabaseName; Date = $targetOrphaned.Date }
    Write-Host "Procesando archivos huérfanos (desacoplados)..." -ForegroundColor Yellow
} elseif ($databasesToArchive.Count -gt 0) {
    $processOrphaned = $false
    $targetDatabase = $databasesToArchive | Select-Object -First 1
    Write-Host "Procesando base de datos activa..." -ForegroundColor Cyan
} else {
    Write-Host "No hay bases de datos que requieran archivo." -ForegroundColor Green
    Write-Host "Todas las bases de datos están dentro del período de retención y no hay archivos huérfanos." -ForegroundColor Green
    Write-Host ""
    exit 0
}
Write-Host ""

Write-Host "Base de datos/archivos seleccionados para archivo:" -ForegroundColor Cyan
Write-Host "  Nombre: $($targetDatabase.Name)" -ForegroundColor White
Write-Host "  Fecha: $($targetDatabase.Date.ToString('yyyy-MM'))" -ForegroundColor White
Write-Host "  Antigüedad: $([math]::Round(($now - $targetDatabase.Date).TotalDays / 30, 1)) meses" -ForegroundColor White
if ($processOrphaned) {
    Write-Host "  Tipo: Archivos huérfanos (desacoplados)" -ForegroundColor Yellow
} else {
    Write-Host "  Tipo: Base de datos activa" -ForegroundColor Gray
}
Write-Host ""

# Obtener archivos físicos
if ($processOrphaned) {
    # Ya tenemos los archivos de los huérfanos
    $physicalFiles = $targetFiles
} else {
    Write-Host "Obteniendo información de archivos físicos..." -ForegroundColor Yellow
    try {
        $physicalFiles = Get-DatabasePhysicalFiles -ServerInstance $SqlServerInstance -DatabaseName $targetDatabase.Name
    } catch {
        Write-Host ""
        Write-Host "Error: No se pudieron obtener los archivos físicos." -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

if ($physicalFiles.MDF.Count -eq 0 -or $physicalFiles.LDF.Count -eq 0) {
    Write-Host ""
    Write-Host "Error: No se encontraron archivos MDF o LDF para la base de datos." -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host "  Archivos encontrados:" -ForegroundColor Green
$physicalFiles.MDF | ForEach-Object { Write-Host "    MDF: $_" -ForegroundColor Gray }
$physicalFiles.LDF | ForEach-Object { Write-Host "    LDF: $_" -ForegroundColor Gray }
Write-Host ""

# Calcular espacio que se liberará
$totalSizeMB = [math]::Round((($physicalFiles.MDF + $physicalFiles.LDF) | Where-Object { Test-Path $_ } | ForEach-Object { (Get-Item $_).Length } | Measure-Object -Sum).Sum / 1MB, 2)

Write-Host "Espacio que se liberará: $totalSizeMB MB" -ForegroundColor Cyan
Write-Host ""

# Proceso de archivo
Write-Host "=== Iniciando Proceso de Archivo ===" -ForegroundColor Cyan
Write-Host ""

$detached = $false
$nasConnection = $null
$zipPath = $null
$zipCreated = $false

try {
    # 1. Conectar al NAS
    Write-Host "[1/6] Conectando al NAS..." -ForegroundColor Yellow
    $nasConnection = Connect-ToNAS -NasPath $NasArchivePath -CredentialsXmlPath $CredentialsXmlPath
    $nasDrive = $nasConnection.Drive
    $nasRoot = $nasConnection.Root
    Write-Host ""
    
    # 2. Detach de la base de datos (solo si no son archivos huérfanos)
    if (-not $processOrphaned) {
        Write-Host "[2/6] Desacoplando base de datos..." -ForegroundColor Yellow
        $null = Invoke-DetachDatabase -ServerInstance $SqlServerInstance -DatabaseName $targetDatabase.Name
        $detached = $true
        Write-Host ""
    } else {
        Write-Host "[2/6] Archivos ya desacoplados (huérfanos). Omitiendo paso de detach." -ForegroundColor Gray
        Write-Host ""
    }
    
    # 3. Comprimir archivos directamente en el NAS
    Write-Host "[3/6] Comprimiendo archivos directamente en el NAS..." -ForegroundColor Yellow
    $zipFileName = "$($targetDatabase.Name).7z"
    $zipPath = Join-Path $nasRoot $zipFileName
    
    $null = Invoke-CompressDatabaseFiles -MdfFiles $physicalFiles.MDF -LdfFiles $physicalFiles.LDF -OutputZipPath $zipPath -SevenZipExecutable $SevenZipPath
    $zipCreated = $true
    Write-Host ""
    
    # 4. Verificar integridad del archivo 7z
    Write-Host "[4/6] Verificando integridad del archivo 7z..." -ForegroundColor Yellow
    $null = Test-ZipIntegrity -ZipPath $zipPath -SevenZipExecutable $SevenZipPath
    Write-Host ""
    
    # 5. Eliminar archivos locales
    Write-Host "[5/6] Eliminando archivos locales..." -ForegroundColor Yellow
    ($physicalFiles.MDF + $physicalFiles.LDF) | Where-Object { Test-Path $_ } | ForEach-Object { Remove-Item $_ -Force -ErrorAction Stop }
    Write-Host "  Archivos eliminados." -ForegroundColor Green
    Write-Host ""
    
    # 6. Desconectar del NAS
    Remove-PSDrive -Name $nasDrive -Force -ErrorAction SilentlyContinue
    $nasConnection = $null
    Write-Host ""
    
    # 7. Crear nueva base de datos para el mes siguiente (solo si se archivó una base activa)
    $newDatabaseName = $null
    if (-not $processOrphaned) {
        Write-Host "[6/6] Creando nueva base de datos..." -ForegroundColor Yellow
        $newDatabaseName = "$DatabaseNamePattern$($now.AddMonths(1).ToString('yyyyMM'))"
        
        $existingDbs = Get-LogDatabases -ServerInstance $SqlServerInstance -Pattern $DatabaseNamePattern
        if ($existingDbs.Name -contains $newDatabaseName) {
            Write-Host "  La base de datos $newDatabaseName ya existe." -ForegroundColor Yellow
        } else {
            $null = Invoke-CreateNewLogDatabase -ServerInstance $SqlServerInstance -DatabaseName $newDatabaseName -SqlDataPath $SqlDataPath
        }
    }
    Write-Host ""
    
    Write-Host "=== Proceso Completado Exitosamente ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Resumen:" -ForegroundColor Cyan
    Write-Host "  Base de datos/archivos archivados: $($targetDatabase.Name)" -ForegroundColor White
    Write-Host "  Espacio liberado: $totalSizeMB MB" -ForegroundColor White
    Write-Host "  Archivo en NAS: $NasArchivePath\$zipFileName" -ForegroundColor White
    if ($newDatabaseName) {
        Write-Host "  Nueva base de datos: $newDatabaseName" -ForegroundColor White
    }
    Write-Host ""
    
    exit 0
    
} catch {
    Write-Host ""
    Write-Host "=== Error Durante el Proceso ===" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    # Limpiar: Eliminar archivo temporal si fue creado
    if ($zipCreated -and $zipPath -and $nasConnection) {
        Write-Host "Eliminando archivo temporal en el NAS..." -ForegroundColor Yellow
        try {
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force -ErrorAction Stop
                Write-Host "  Archivo temporal eliminado exitosamente." -ForegroundColor Green
            }
        } catch {
            Write-Host "  Advertencia: No se pudo eliminar el archivo temporal: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Limpiar: Desconectar del NAS si está mapeado
    if ($nasConnection) {
        Remove-PSDrive -Name $nasConnection.Drive -Force -ErrorAction SilentlyContinue
    }
    
    # Rollback: Re-attach de la base de datos si fue desacoplada (solo si no eran archivos huérfanos)
    if ($detached -and -not $processOrphaned -and $physicalFiles.MDF.Count -gt 0 -and (Test-Path $physicalFiles.MDF[0])) {
        Write-Host "Intentando restaurar la base de datos..." -ForegroundColor Yellow
        try {
            $escapedName = $targetDatabase.Name.Replace("'", "''")
            $attachQuery = "CREATE DATABASE [$escapedName] ON (FILENAME = '$($physicalFiles.MDF[0].Replace("'", "''"))'), (FILENAME = '$($physicalFiles.LDF[0].Replace("'", "''"))') FOR ATTACH;"
            Invoke-SqlcmdQuery -ServerInstance $SqlServerInstance -Query $attachQuery | Out-Null
            Write-Host "  Base de datos restaurada exitosamente." -ForegroundColor Green
        } catch {
            Write-Host "  Error al restaurar: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    exit 1
}
