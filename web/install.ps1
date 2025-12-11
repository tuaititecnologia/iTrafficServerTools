# iTraffic Server Tools - Installer Script
# Installs SQL Server management scripts to %SystemDrive%\Scripts
# Usage: irm https://tuaiti.com.ar/scripts/itraffic | iex

$ErrorActionPreference = 'Continue'

$ScriptsRepo = "https://raw.githubusercontent.com/tuaititecnologia/iTrafficServerTools/main/Scripts"
$ScriptsApiUrl = "https://api.github.com/repos/tuaititecnologia/iTrafficServerTools/contents/Scripts"
$InstallPath = "$env:SystemDrive\Scripts"

# Check administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ""
Write-Host "=== iTraffic Server Tools - Installer ===" -ForegroundColor Cyan
Write-Host ""

if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required." -ForegroundColor Red
    pause
    exit 1
}

# Create directory
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Remove old iTraffic folder if it exists (replaced by Tools)
$oldItrafficPath = Join-Path $InstallPath "iTraffic"
if (Test-Path $oldItrafficPath) {
    Write-Host "Removing old 'iTraffic' folder (replaced by 'Tools')..." -ForegroundColor Yellow
    try {
        Remove-Item -Path $oldItrafficPath -Recurse -Force
        Write-Host "  OK - Old 'iTraffic' folder removed" -ForegroundColor Green
    } catch {
        Write-Host "  WARNING - Could not remove old 'iTraffic' folder: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Function to recursively get all files from GitHub
function Get-AllFiles {
    param(
        [string]$ApiUrl,
        [string]$BasePath = "Scripts"
    )
    
    $allFiles = @()
    
    try {
        $items = (Invoke-WebRequest -Uri $ApiUrl -UseBasicParsing).Content | ConvertFrom-Json
    } catch {
        # Fallback: use WebClient
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "PowerShell")
            $json = $webClient.DownloadString($ApiUrl)
            $webClient.Dispose()
            $items = $json | ConvertFrom-Json
        } catch {
            throw "Failed to get files list: $($_.Exception.Message)"
        }
    }
    
    foreach ($item in $items) {
        if ($item.type -eq "file") {
            $allFiles += @{
                Path = $item.path
                Name = $item.name
            }
        } elseif ($item.type -eq "dir") {
            # Recursively get files from subdirectory
            $subDirUrl = $item.url
            $subFiles = Get-AllFiles -ApiUrl $subDirUrl -BasePath $item.path
            $allFiles += $subFiles
        }
    }
    
    return $allFiles
}

# Get all files recursively from GitHub
Write-Host "Downloading files..." -ForegroundColor Yellow
try {
    $allFiles = Get-AllFiles -ApiUrl $ScriptsApiUrl
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit 1
}

# Download each file
foreach ($file in $allFiles) {
    $relativePath = $file.Path -replace "^Scripts/", ""
    $fileUrl = "$ScriptsRepo/$relativePath"
    $filePath = Join-Path $InstallPath $relativePath
    $fileDir = Split-Path $filePath -Parent
    
    try {
        # Create subdirectory if needed
        if ($fileDir -and -not (Test-Path $fileDir)) {
            New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
        }
        
        (Invoke-WebRequest -Uri $fileUrl -UseBasicParsing).Content | Out-File -FilePath $filePath -Encoding UTF8 -Force
        Write-Host "  OK $relativePath" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR $relativePath - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Installation completed! Files installed to: $InstallPath" -ForegroundColor Green
Write-Host ""

# Open Explorer in the installation folder
Invoke-Item $InstallPath

