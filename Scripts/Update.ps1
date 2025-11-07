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

irm https://tuaiti.com.ar/scripts/itraffic | iex

