# Fix SSL/TLS for Windows Server 2016 and older systems
# Force TLS 1.2 to work with modern HTTPS endpoints
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$sqlInstallerUrl = "https://go.microsoft.com/fwlink/?linkid=866658"
$sqlInstallerPath = "$env:TEMP\sqlexpress_web.exe"
Invoke-WebRequest -Uri $sqlInstallerUrl -OutFile $sqlInstallerPath
$saPassword = Generate-UserPassword
$configFilePath = "$env:TEMP\ConfigurationFile.ini"
$currentUser = "$env:USERDOMAIN\$env:USERNAME"
$configContent = @"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE
INSTANCENAME="SQLEXPRESS"
SECURITYMODE=SQL
SAPWD="$saPassword"
SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
SQLSYSADMINACCOUNTS="$currentUser"
AGTSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
TCPENABLED=1
NPENABLED=0
BROWSERSVCSTARTUPTYPE="Automatic"
IACCEPTSQLSERVERLICENSETERMS="True"
QUIET="True"
ENU="True"
"@
$configContent | Out-File -Encoding ASCII -FilePath $configFilePath
Start-Process -FilePath $sqlInstallerPath -ArgumentList "/ConfigurationFile=$configFilePath" -Wait
$saPassword | Out-File -FilePath "$env:USERPROFILE\Desktop\sql-sa-password.txt"

# Configurar puerto TCP
$tcpBasePath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL15.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp"
Get-ChildItem -Path $tcpBasePath | Where-Object { $_.Name -match "IP\d+" } | ForEach-Object {
    Set-ItemProperty -Path $_.PsPath -Name "TcpDynamicPorts" -Value ""
    Set-ItemProperty -Path $_.PsPath -Name "Enabled" -Value 1
}
$ipAllPath = Join-Path $tcpBasePath "IPAll"
Set-ItemProperty -Path $ipAllPath -Name "TcpDynamicPorts" -Value ""
Set-ItemProperty -Path $ipAllPath -Name "TcpPort" -Value "1433"
Restart-Service -Name 'MSSQL$SQLEXPRESS'