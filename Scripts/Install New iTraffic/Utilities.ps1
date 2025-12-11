(-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Winget no está disponible." -ForegroundColor Red
    exit
}
winget install --id 7zip.7zip --silent --accept-package-agreements --accept-source-agreements
winget install --id Notepad++.Notepad++ --silent --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.SQLServerManagementStudio --silent --accept-package-agreements --accept-source-agreements