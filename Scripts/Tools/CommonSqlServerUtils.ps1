# Common SQL Server helper functions shared across scripts

# Verificar si el script se está ejecutando directamente
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  ADVERTENCIA" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Este archivo contiene funciones de utilidad y NO debe ejecutarse directamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Para usar estas funciones, impórtelas en su script usando:" -ForegroundColor Cyan
    Write-Host "  . .\CommonSqlServerUtils.ps1" -ForegroundColor Green
    Write-Host ""
    Write-Host "O desde otra ubicación:" -ForegroundColor Cyan
    Write-Host "  . `$PSScriptRoot\CommonSqlServerUtils.ps1" -ForegroundColor Green
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Salir del script
    exit 1
}

function Get-SQLServerInstances {
    $instances = [System.Collections.ArrayList]@()
    $serverName = $env:COMPUTERNAME

    if ([string]::IsNullOrEmpty($serverName)) {
        $serverName = [System.Net.Dns]::GetHostName()
    }

    $regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    if (Test-Path $regPath) {
        $regProperties = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if ($regProperties) {
            $regPropertyNames = $regProperties.PSObject.Properties.Name | Where-Object {
                $_ -ne "PSPath" -and
                $_ -ne "PSParentPath" -and
                $_ -ne "PSChildName" -and
                $_ -ne "PSDrive" -and
                $_ -ne "PSProvider"
            }

            foreach ($regInstanceName in $regPropertyNames) {
                try {
                    $serviceName = if ($regInstanceName -eq "MSSQLSERVER") {
                        "MSSQLSERVER"
                    } else {
                        "MSSQL`$$regInstanceName"
                    }

                    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

                    if ($service -and $service.Status -eq 'Running') {
                        $instanceName = if ($regInstanceName -eq "MSSQLSERVER") {
                            $serverName
                        } else {
                            "$serverName\$regInstanceName"
                        }

                        if ($instances -notcontains $instanceName) {
                            [void]$instances.Add($instanceName)
                        }
                    }
                } catch {
                    continue
                }
            }
        }
    }

    return $instances.ToArray()
}

function Invoke-SqlcmdQuery {
    param(
        [string]$ServerInstance,
        [string]$Query
    )

    $tempFile = [System.IO.Path]::GetTempFileName() + ".sql"

    try {
        # Usar .NET para compatibilidad con PowerShell 4.0 (Windows Server 2012 R2)
        # WriteAllText es compatible y no requiere -NoNewline
        [System.IO.File]::WriteAllText($tempFile, $Query, [System.Text.Encoding]::UTF8)
        $output = & sqlcmd -S $ServerInstance -i $tempFile -W -h -1 -s "`t" -w 1000 -b 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Error executing sqlcmd: $output"
        }

        return $output
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

