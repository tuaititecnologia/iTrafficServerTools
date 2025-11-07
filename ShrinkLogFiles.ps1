# Script para reducir archivos LDF excesivos en SQL Server
# Compatible con Windows Server 2012 R2
# Usa sqlcmd para compatibilidad máxima
# Autor: Generado automáticamente

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    Write-Host "No se encontró la utilidad sqlcmd. Instale SQL Server Command Line Utilities o el Feature Pack." -ForegroundColor Red
    pause
    exit
}

$commonLibraryPath = Join-Path -Path $PSScriptRoot -ChildPath 'CommonSqlServerUtils.ps1'
if (-not (Test-Path $commonLibraryPath)) {
    Write-Host "No se encontró la librería requerida: $commonLibraryPath" -ForegroundColor Red
    pause
    exit
}

. $commonLibraryPath

# Función para obtener bases de datos y sus tamaños
function Get-DatabaseFileSizes {
    param(
        [string]$ServerInstance
    )
    
    $query = @"
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    name AS LogicalFileName,
    type_desc AS FileType,
    size * 8.0 / 1024 AS SizeMB,
    physical_name AS PhysicalPath
FROM sys.master_files
WHERE type_desc IN ('ROWS', 'LOG')
ORDER BY DB_NAME(database_id), type_desc
"@
    
    $databases = @{}
    
    $results = @()

    try {
        $output = Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query

        # Parsear resultados tabulares (saltar líneas de encabezado, separadores y vacías)
        $results = $output | Where-Object { 
            $_ -and 
            $_.Trim() -ne "" -and
            $_ -notmatch "^-+$" -and 
            $_ -notmatch "^DatabaseName" -and
            $_ -match "`t"
        } | ForEach-Object {
            $parts = $_ -split "`t"
            if ($parts.Count -ge 5) {
                try {
                    $dbName = $parts[0].Trim()
                    $logicalName = $parts[1].Trim()
                    $fileType = $parts[2].Trim()
                    $sizeMBStr = $parts[3].Trim()
                    $physicalPath = $parts[4].Trim()
                    
                    # Intentar convertir el tamaño
                    try {
                        $sizeMB = [double]$sizeMBStr
                        if ($sizeMB -ge 0) {
                            [PSCustomObject]@{
                                DatabaseName = $dbName
                                LogicalFileName = $logicalName
                                FileType = $fileType
                                SizeMB = $sizeMB
                                PhysicalPath = $physicalPath
                            }
                        }
                    } catch {
                        # Ignorar si no se puede convertir
                    }
                } catch {
                    # Ignorar líneas que no se pueden parsear
                }
            }
        }
    } catch {
        Write-Host "Error obteniendo información de archivos: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    foreach ($row in $results) {
        if (-not $databases.ContainsKey($row.DatabaseName)) {
            $databases[$row.DatabaseName] = @{
                MDFSize = 0
                LDFSize = 0
                MDFFiles = @()
                LDFFiles = @()
            }
        }
        
        if ($row.FileType -eq "ROWS") {
            $databases[$row.DatabaseName].MDFSize += $row.SizeMB
            $databases[$row.DatabaseName].MDFFiles += $row.LogicalFileName
        } elseif ($row.FileType -eq "LOG") {
            $databases[$row.DatabaseName].LDFSize += $row.SizeMB
            $databases[$row.DatabaseName].LDFFiles += $row.LogicalFileName
        }
    }
    
    return $databases
}

# Script SQL embebido para reducir archivos LDF
$embeddedShrinkLogScript = @"
declare @logname varchar(100)
declare @dbname varchar(100)
declare @vQuery nvarchar(max)

-- Este valor será reemplazado dinámicamente por el script de PowerShell --
set @dbname=''
-- -------------------------------------------------------------------------

SET @vQuery=N'SELECT @logname=name from ' + @dbname + N'.sys.sysfiles where name like ''%Log'''

EXEC sp_executeSQL 
	@Query = @vQuery, 
	@Params = N'@logname varchar(100) OUTPUT', 
	@logname = @logname OUTPUT

SET @vQuery =           'USE ' + @dbname + ';'
SET @vQuery = @vQuery + 'ALTER DATABASE ' + @dbname + ' SET RECOVERY SIMPLE;'
SET @vQuery = @vQuery + 'DBCC SHRINKFILE(' + @logname + ',1);'
SET @vQuery = @vQuery + 'ALTER DATABASE ' + @dbname + ' SET RECOVERY FULL;'

EXEC sp_executeSQL @Query = @vQuery
"@

# Función para ejecutar el script de reducción
function Invoke-ShrinkLogFile {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName
    )
    
    # Usar el script SQL embebido y reemplazar el nombre de la base de datos
    $sqlScript = $embeddedShrinkLogScript
    
    # Reemplazar el nombre de la base de datos (manejar diferentes formatos)
    # Patrón: set @dbname='CUALQUIER_NOMBRE' (con o sin espacios alrededor del =)
    $pattern = "(?i)(set\s+@dbname\s*=\s*)'[^']*'"
    $regex = [regex]$pattern
    $sqlScript = $regex.Replace(
        $sqlScript,
        { param($m) "$($m.Groups[1].Value)'$DatabaseName'" },
        1
    )
    
    # Validar que el reemplazo se hizo correctamente
    if (-not ($sqlScript -match "(?i)set\s+@dbname\s*=\s*'$([regex]::Escape($DatabaseName))'")) {
        Write-Host "ERROR: No se pudo verificar el reemplazo del nombre de la base de datos en el script SQL" -ForegroundColor Red
        throw "No se pudo reemplazar el nombre de la base de datos en el script SQL"
    }
    
    Write-Host "  Script SQL modificado con nombre de base de datos: $DatabaseName" -ForegroundColor Gray
    
    try {
        Write-Host "Ejecutando script de reducción para base de datos: $DatabaseName" -ForegroundColor Yellow
        
        Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $sqlScript | Out-Null
        Write-Host "Script ejecutado correctamente" -ForegroundColor Green
    } catch {
        Write-Host "Error ejecutando script: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ===== INICIO DEL SCRIPT PRINCIPAL =====

Write-Host "`n=== Script de Reducción de Archivos LDF de SQL Server ===" -ForegroundColor Cyan
Write-Host ""

# Obtener instancias de SQL Server
Write-Host "Buscando instancias de SQL Server..." -ForegroundColor Yellow
$instances = @(Get-SQLServerInstances)

if ($instances.Count -eq 0) {
    Write-Host "No se encontraron instancias de SQL Server con servicio iniciado." -ForegroundColor Red
    pause
    exit
}

Write-Host "Instancias encontradas: $($instances.Count)" -ForegroundColor Green

# Si hay más de una instancia, permitir selección
$selectedInstance = $null
if ($instances.Count -eq 1) {
    $selectedInstance = $instances[0]
    Write-Host "Usando instancia: $selectedInstance" -ForegroundColor Green
} else {
    Write-Host "`nInstancias disponibles:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $instances.Count; $i++) {
        $instanceNum = $i + 1
        $instanceName = $instances[$i]
        Write-Host "  [$instanceNum] $instanceName" -ForegroundColor White
    }
    
    do {
        $selection = Read-Host "`nSeleccione el número de la instancia (1-$($instances.Count))"
        $selectionNum = [int]$selection - 1
        if ($selectionNum -ge 0 -and $selectionNum -lt $instances.Count) {
            $selectedInstance = $instances[$selectionNum]
            break
        } else {
            Write-Host "Selección inválida. Por favor ingrese un número entre 1 y $($instances.Count)" -ForegroundColor Red
        }
    } while ($true)
    
    Write-Host "Instancia seleccionada: $selectedInstance" -ForegroundColor Green
}

# Obtener información de bases de datos
Write-Host "`nAnalizando bases de datos..." -ForegroundColor Yellow
try {
    $databases = Get-DatabaseFileSizes -ServerInstance $selectedInstance
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit
}

if ($databases.Count -eq 0) {
    Write-Host "No se encontraron bases de datos." -ForegroundColor Yellow
    pause
    exit
}

# Analizar bases de datos con LDF excesivo
Write-Host "`n=== Análisis de Archivos LDF ===" -ForegroundColor Cyan
$databasesToShrink = @()
$ldfRatioThreshold = 0.10  # 10%
$ldfSizeThresholdMB = 100  # 100 MB

foreach ($dbName in $databases.Keys) {
    $dbInfo = $databases[$dbName]
    
    # Excluir bases de datos del sistema
    if ($dbName -in @("master", "model", "msdb", "tempdb")) {
        continue
    }
    
    # Verificar si tiene archivos MDF y LDF
    if ($dbInfo.MDFSize -eq 0 -or $dbInfo.LDFSize -eq 0) {
        continue
    }
    
    $percentage = $dbInfo.LDFSize / $dbInfo.MDFSize
    
    Write-Host "`nBase de datos: $dbName" -ForegroundColor White
    Write-Host "  Tamaño MDF: $([math]::Round($dbInfo.MDFSize, 2)) MB" -ForegroundColor Gray
    Write-Host "  Tamaño LDF: $([math]::Round($dbInfo.LDFSize, 2)) MB" -ForegroundColor Gray
    $percentText = "$([math]::Round($percentage * 100, 2))%"
    $ratioExceeds = $percentage -gt $ldfRatioThreshold
    $color = if ($ratioExceeds) { "Red" } else { "Green" }
    Write-Host "  Porcentaje LDF/MDF: $percentText" -ForegroundColor $color
    $ldfSizeExceeds = $dbInfo.LDFSize -gt $ldfSizeThresholdMB
    Write-Host "  LDF > 100 MB: $(if ($ldfSizeExceeds) { 'Sí' } else { 'No' })" -ForegroundColor $(if ($ldfSizeExceeds) { "Yellow" } else { "Green" })
    
    if ($ldfSizeExceeds -and $ratioExceeds) {
        Write-Host '  [REQUIERE REDUCCIÓN]' -ForegroundColor Red
        $databasesToShrink += @{
            Name = $dbName
            MDFSize = $dbInfo.MDFSize
            LDFSize = $dbInfo.LDFSize
            Percentage = $percentage
        }
    } else {
        Write-Host '  [OK]' -ForegroundColor Green
    }
}

# Procesar bases de datos que requieren reducción
if ($databasesToShrink.Count -eq 0) {
    Write-Host "`nNo se encontraron bases de datos con archivos LDF excesivos." -ForegroundColor Green
    pause
    exit
}

Write-Host "`n=== Bases de Datos que Requieren Reducción ===" -ForegroundColor Cyan
Write-Host "Se encontraron $($databasesToShrink.Count) base(s) de datos con LDF > 100 MB y LDF > 10% del MDF" -ForegroundColor Yellow

$confirmation = Read-Host "`n¿Desea proceder con la reducción de las bases listadas? (S/N)"
if ($null -eq $confirmation) {
    $confirmation = ""
}
$confirmationClean = $confirmation.Trim().ToUpperInvariant()
if ($confirmationClean -notin @("S", "SI", "Y", "YES")) {
    Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
    pause
    exit
}

foreach ($db in $databasesToShrink) {
    Write-Host "`nProcesando: $($db.Name)" -ForegroundColor Cyan
    Write-Host "  Tamaño LDF actual: $([math]::Round($db.LDFSize, 2)) MB" -ForegroundColor White
    
    try {
        Invoke-ShrinkLogFile -ServerInstance $selectedInstance -DatabaseName $db.Name
        
        # Verificar el nuevo tamaño después de la reducción
        Start-Sleep -Seconds 2
        $updatedDatabases = Get-DatabaseFileSizes -ServerInstance $selectedInstance
        if ($updatedDatabases.ContainsKey($db.Name)) {
            $newLDFSize = $updatedDatabases[$db.Name].LDFSize
            Write-Host "  Tamaño LDF después de reducción: $([math]::Round($newLDFSize, 2)) MB" -ForegroundColor Green
            $reduction = $db.LDFSize - $newLDFSize
            if ($reduction -gt 0) {
                Write-Host "  Espacio liberado: $([math]::Round($reduction, 2)) MB" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  Error procesando $($db.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Proceso Completado ===" -ForegroundColor Cyan
pause

