Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools
Install-WindowsFeature -Name NET-Framework-Features -IncludeAllSubFeature
$wwwrootPath = "$env:SystemDrive\inetpub\wwwroot"
Get-ChildItem -Path $wwwrootPath -Filter "iisstart.*" -ErrorAction SilentlyContinue | Remove-Item -Force
@"
<html>
  <head><title>$client_name</title></head>
  <body><h1>Servidor de $client_name</h1></body>
</html>
"@ | Set-Content -Path (Join-Path $wwwrootPath "index.html")
