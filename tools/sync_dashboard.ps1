# Dashboard Sync Script for EAX TBC Classic Rotations
# Copies root libraries/dashboard.lua to all 29 spec directories
#
# Usage: .\tools\sync_dashboard.ps1

param(
    [switch]$WhatIf = $false
)

$rootFile = "libraries/dashboard.lua"
$specCount = 0
$syncCount = 0
$skipCount = 0
$errorCount = 0

# Colors for output (PowerShell 5.1 compatible)
$green = "Green"
$yellow = "Yellow"
$red = "Red"
$white = "White"

Write-Host "=== EAX Dashboard Sync Tool ===" -ForegroundColor $white
Write-Host ""

# Verify root file exists
if (-not (Test-Path $rootFile)) {
    Write-Host "[ERROR] Root dashboard.lua not found: $rootFile" -ForegroundColor $red
    exit 1
}

Write-Host "Root file: $rootFile" -ForegroundColor $white
Write-Host "Scanning for EAX spec directories..." -ForegroundColor $white
Write-Host ""

# Get all EAX directories
$specDirs = Get-ChildItem -Directory | Where-Object { $_.Name -like "EAX*" }

foreach ($dir in $specDirs) {
    $specCount++
    $targetDir = Join-Path $dir.FullName "libraries"
    $targetFile = Join-Path $targetDir "dashboard.lua"
    
    # Check if libraries directory exists
    if (Test-Path $targetDir) {
        if ($WhatIf) {
            Write-Host "[WOULD SYNC] $($dir.Name)" -ForegroundColor $yellow
        } else {
            try {
                Copy-Item $rootFile $targetFile -Force -ErrorAction Stop
                Write-Host "[SYNCED] $($dir.Name)" -ForegroundColor $green
                $syncCount++
            } catch {
                Write-Host "[ERROR] $($dir.Name): $_" -ForegroundColor $red
                $errorCount++
            }
        }
    } else {
        Write-Host "[SKIP] $($dir.Name) (no libraries folder)" -ForegroundColor $yellow
        $skipCount++
    }
}

Write-Host ""
Write-Host "=== Sync Complete ===" -ForegroundColor $white
Write-Host "Specs found: $specCount" -ForegroundColor $white
if ($WhatIf) {
    Write-Host "Would sync: $specCount" -ForegroundColor $yellow
} else {
    Write-Host "Synced: $syncCount" -ForegroundColor $green
    Write-Host "Skipped: $skipCount" -ForegroundColor $yellow
    Write-Host "Errors: $errorCount" -ForegroundColor $red
}
Write-Host ""

if ($syncCount -eq 0 -and -not $WhatIf) {
    Write-Host "Warning: No specs were synced. Check directory structure." -ForegroundColor $yellow
    exit 1
} elseif ($syncCount -lt 29 -and -not $WhatIf) {
    Write-Host "Warning: Only $syncCount of 29 specs were synced." -ForegroundColor $yellow
    exit 0
} elseif (-not $WhatIf) {
    Write-Host "All $syncCount specs synced successfully!" -ForegroundColor $green
    exit 0
}
