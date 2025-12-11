if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-PackageProvider -Name NuGet -Force
    Install-Module -Name PSWindowsUpdate -Force
}
Import-Module PSWindowsUpdate
$updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot -MicrosoftUpdate
if ($updates.Count -gt 0) {
    Install-WindowsUpdate -AcceptAll -IgnoreReboot -MicrosoftUpdate -AutoReboot
    exit
}