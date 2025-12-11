# Update iTraffic Server Tools
# Usage: irm https://tuaiti.com.ar/scripts/itraffic | iex

Write-Host "Updating iTraffic Server Tools..." -ForegroundColor Yellow
Write-Host ""
Write-Host "This will update the iTraffic Server Tools to the latest version." -ForegroundColor Yellow
Write-Host ""
Write-Host "Do you want to continue? (y/n)" -ForegroundColor Yellow
$continue = Read-Host
if ($continue -ne "y") {
    Write-Host "Update cancelled." -ForegroundColor Red
    exit
}

# Download install.ps1 to a temporary location
$tempPath = [System.IO.Path]::GetTempPath()
$tempScript = Join-Path $tempPath "iTrafficInstall.ps1"

Write-Host "Downloading installer..." -ForegroundColor Yellow
try {
    $installScriptUrl = "https://tuaiti.com.ar/scripts/itraffic"
    Invoke-WebRequest -Uri $installScriptUrl -OutFile $tempScript -UseBasicParsing
    Write-Host "Installer downloaded to temporary location." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to download installer: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit 1
}

# Execute install.ps1 in a new PowerShell process
# This allows Update.ps1 to terminate before install.ps1 tries to delete files
Write-Host "Starting installer in new process..." -ForegroundColor Yellow
Write-Host "This window will close. The installer will run in a new window." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# Start install.ps1 in a new PowerShell window and exit this process
Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" -Verb RunAs

# Exit immediately so Update.ps1 is no longer running when install.ps1 deletes files
exit

