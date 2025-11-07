# Set all databases to FULL recovery mode
# Requires sqlcmd utility

# Ensure sqlcmd is available
if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    Write-Host "sqlcmd utility not found. Please install SQL Server Command Line Utilities or the SQL Server feature pack." -ForegroundColor Red
    pause
    exit
}

$commonLibraryPath = Join-Path -Path $PSScriptRoot -ChildPath 'CommonSqlServerUtils.ps1'
if (-not (Test-Path $commonLibraryPath)) {
    Write-Host "Required library not found: $commonLibraryPath" -ForegroundColor Red
    pause
    exit
}

. $commonLibraryPath

function Get-UserDatabases {
    param(
        [string]$ServerInstance
    )

    $query = @"
SET NOCOUNT ON;
SELECT name, recovery_model_desc
FROM sys.databases
WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')
ORDER BY name;
"@

    $output = Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query
    $databases = @()

    foreach ($line in $output) {
        if (-not $line) { continue }
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed -match "^\(.* rows affected\)$") { continue }
        $parts = $line -split "`t"
        if ($parts.Count -ge 2) {
            $dbName = $parts[0].Trim()
            $recoveryModel = $parts[1].Trim()
            if ($dbName) {
                $databases += [PSCustomObject]@{
                    Name = $dbName
                    RecoveryModel = $recoveryModel
                }
            }
        }
    }

    return $databases
}

function Set-DatabaseRecoveryFull {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName
    )

    $escapedName = $DatabaseName.Replace("]", "]]")
    $query = @"
SET NOCOUNT ON;
ALTER DATABASE [$escapedName] SET RECOVERY FULL;
"@

    Invoke-SqlcmdQuery -ServerInstance $ServerInstance -Query $query | Out-Null
}

# Detect SQL Server instances
Write-Host "`nDetecting SQL Server instances..." -ForegroundColor Cyan
$instances = @(Get-SQLServerInstances)

if (-not $instances -or $instances.Count -eq 0) {
    Write-Host "No SQL Server instances found." -ForegroundColor Red
    pause
    exit
}

$selectedInstance = $null

if ($instances.Count -eq 1) {
    $selectedInstance = $instances[0]
    Write-Host "`nUsing SQL Server instance: $selectedInstance" -ForegroundColor Green
} else {
    Write-Host "`nAvailable SQL Server instances:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $instances.Count; $i++) {
        $instanceNumber = $i + 1
        Write-Host "  [$instanceNumber] $($instances[$i])" -ForegroundColor White
    }
    Write-Host ""
}

try {
    if (-not $selectedInstance) {
        $selection = Read-Host "Select instance number (1-$($instances.Count))"
        $selectedIndex = [int]$selection - 1
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $instances.Count) {
            Write-Host "Invalid selection." -ForegroundColor Red
            pause
            exit
        }
        $selectedInstance = $instances[$selectedIndex]
    }

    $serverInstance = $selectedInstance

    Write-Host "`nConnecting to: $serverInstance" -ForegroundColor Green
    
    # Get databases with recovery model using sqlcmd
    Write-Host "`nRetrieving databases..." -ForegroundColor Cyan
    $databases = Get-UserDatabases -ServerInstance $serverInstance

    if (-not $databases -or $databases.Count -eq 0) {
        Write-Host "No user databases found." -ForegroundColor Yellow
        pause
        exit
    }
    
    # Display databases with recovery model
    Write-Host "`nDatabases and current recovery mode:" -ForegroundColor Yellow
    Write-Host ("{0,-40} {1,-15}" -f "Database Name", "Recovery Mode") -ForegroundColor Cyan
    Write-Host ("-" * 55) -ForegroundColor Cyan
    
    foreach ($db in $databases) {
        $recoveryModel = $db.RecoveryModel
        Write-Host ("{0,-40} {1,-15}" -f $db.Name, $recoveryModel) -ForegroundColor White
    }
    
    Write-Host ""
    $confirm = Read-Host "Do you want to change ALL databases to FULL recovery mode? (Y/N)"
    
    if ($confirm -eq 'Y' -or $confirm -eq 'y') {
        Write-Host "`nChanging recovery mode to FULL..." -ForegroundColor Yellow
        
        $changedCount = 0
        $skippedCount = 0
        
        foreach ($db in $databases) {
            $currentModel = $db.RecoveryModel
            $isFull = $false
            if ($currentModel) {
                $isFull = ($currentModel.ToUpperInvariant() -eq 'FULL')
            }

            if (-not $isFull) {
                try {
                    Set-DatabaseRecoveryFull -ServerInstance $serverInstance -DatabaseName $db.Name
                    $db.RecoveryModel = 'FULL'
                    Write-Host "  Changed: $($db.Name) -> FULL" -ForegroundColor Green
                    $changedCount++
                } catch {
                    Write-Host "  Error changing $($db.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "  Skipped: $($db.Name) (already FULL)" -ForegroundColor Gray
                $skippedCount++
            }
        }
        
        Write-Host "`nSummary:" -ForegroundColor Cyan
        Write-Host "  Changed: $changedCount database(s)" -ForegroundColor Green
        Write-Host "  Skipped: $skippedCount database(s)" -ForegroundColor Gray
    } else {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
pause

