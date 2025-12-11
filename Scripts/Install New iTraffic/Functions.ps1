function Generate-RandomString {
    $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return -join ($characters.ToCharArray() | Get-Random -Count 12)
}

function Generate-UserPassword {
    $upper = -join ((65..90) | Get-Random -Count 2 | ForEach-Object {[char]$_})
    $lower = -join ((97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_})
    $digit = -join ((48..57) | Get-Random -Count 2 | ForEach-Object {[char]$_})
    $symbol = -join ((33,35,36,37,38,64) | Get-Random -Count 1 | ForEach-Object {[char]$_})
    return ($upper + $lower + $digit + $symbol)
}
