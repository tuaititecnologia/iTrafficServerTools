<?php
/**
 * iTraffic Server Tools - Installer Endpoint
 * Serves install.ps1 content for PowerShell installation
 * URL: https://tuaiti.com.ar/scripts/itraffic
 */

header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-cache, must-revalidate');
header('Expires: Sat, 26 Jul 1997 05:00:00 GMT');

// Get the directory where this PHP file is located
$scriptDir = __DIR__;
$installScript = $scriptDir . '/install.ps1';

// Check if install.ps1 exists
if (!file_exists($installScript)) {
    http_response_code(404);
    echo "# ERROR: install.ps1 not found\n";
    exit;
}

// Read and output the install script
readfile($installScript);

