if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Winget no está disponible." -ForegroundColor Red
    exit
}
winget install --id 7zip.7zip --source winget --silent --accept-package-agreements --accept-source-agreements
winget install --id Notepad++.Notepad++ --source winget --silent --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.SQLServerManagementStudio --source winget --silent --accept-package-agreements --accept-source-agreements