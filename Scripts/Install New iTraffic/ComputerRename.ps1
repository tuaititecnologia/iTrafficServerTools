w_computer_name = "$client_code-iTraffic"
$current_name = $env:COMPUTERNAME
if ($current_name -ieq $new_computer_name) {
    Write-Host "El equipo ya tiene el nombre correcto: $current_name"
} else {
    Rename-Computer -NewName $new_computer_name -Force
    Write-Host "Equipo renombrado. Se aplicará tras reinicio."
}