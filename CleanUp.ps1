 # Eliminar logs de todas las aplicaciones en wwwroot
$wwwrootPath = "C:\inetpub\wwwroot"
$logFolders = Get-ChildItem -Path $wwwrootPath -Recurse -Directory -Filter "Log" | Where-Object { $_.FullName -like "*\App_Data\Log" }

foreach ($logFolder in $logFolders) {
    Write-Host "Limpiando logs en: $($logFolder.FullName)" -ForegroundColor Yellow
    $filesToDelete = Get-ChildItem -Path $logFolder.FullName -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) }
    if ($filesToDelete) {
        $filesToDelete | Remove-Item -Force
        Write-Host "  Eliminados $($filesToDelete.Count) archivo(s)" -ForegroundColor Green
    } else {
        Write-Host "  No se encontraron archivos para eliminar" -ForegroundColor Gray
    }
}

# Eliminar logs de IIS en todas las subcarpetas de LogFiles
$iisLogPath = "C:\inetpub\logs\LogFiles"
$iisLogFolders = Get-ChildItem -Path $iisLogPath -Directory

foreach ($iisFolder in $iisLogFolders) {
    Write-Host "Limpiando logs de IIS en: $($iisFolder.FullName)" -ForegroundColor Yellow
    $filesToDelete = Get-ChildItem -Path $iisFolder.FullName -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) }
    if ($filesToDelete) {
        $filesToDelete | Remove-Item -Force
        Write-Host "  Eliminados $($filesToDelete.Count) archivo(s)" -ForegroundColor Green
    } else {
        Write-Host "  No se encontraron archivos para eliminar" -ForegroundColor Gray
    }
}

# Eliminar logs de SpoolfisNet
Restart-Service SpoolfisNet
$programFilesPaths = @("C:\Program Files", "C:\Program Files (x86)")

foreach ($programPath in $programFilesPaths) {
    if (Test-Path $programPath) {
        $spoolfisFolders = Get-ChildItem -Path $programPath -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Spoolfis*" }
        
        foreach ($spoolfisFolder in $spoolfisFolders) {
            Write-Host "Limpiando logs de SpoolfisNet en: $($spoolfisFolder.FullName)" -ForegroundColor Yellow
            $filesToDelete = Get-ChildItem -Path $spoolfisFolder.FullName -Filter "*.txt.*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "log-file.txt" }
            if ($filesToDelete) {
                $deletedCount = 0
                foreach ($file in $filesToDelete) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        $deletedCount++
                    } catch {
                        Write-Host "  No se pudo eliminar $($file.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
                if ($deletedCount -gt 0) {
                    Write-Host "  Eliminados $deletedCount archivo(s)" -ForegroundColor Green
                }
            } else {
                Write-Host "  No se encontraron archivos para eliminar" -ForegroundColor Gray
            }
        }
    }
}

# Limpiar carpeta barcode
Get-ChildItem -Path "C:\inetpub\barcode\*.*" | Remove-Item

pause
 
