# Sylvanas Plugin Deployment Script
# Run this to copy all class plugins to the Sylvanas Scripts folder

param(
    [Parameter(Mandatory=$true)]
    [string]$SylvanasScriptsPath
)

$ErrorActionPreference = "Stop"

$sourcePath = "C:\testscripts\sylvanas-rotations"
$classes = @("druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior")

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Sylvanas Rotation Plugin Deployment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $sourcePath" -ForegroundColor Gray
Write-Host "Destination: $SylvanasScriptsPath" -ForegroundColor Gray
Write-Host ""

# Verify source exists
if (-not (Test-Path $sourcePath)) {
    Write-Error "Source path not found: $sourcePath"
    exit 1
}

# Create destination if it doesn't exist
if (-not (Test-Path $SylvanasScriptsPath)) {
    Write-Host "Creating destination directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $SylvanasScriptsPath -Force | Out-Null
}

$deployed = 0
$failed = 0

foreach ($class in $classes) {
    $source = Join-Path $sourcePath $class
    $dest = Join-Path $SylvanasScriptsPath $class
    
    if (Test-Path $source) {
        try {
            Write-Host "Deploying $class... " -NoNewline
            
            # Remove old version if exists
            if (Test-Path $dest) {
                Remove-Item -Path $dest -Recurse -Force
            }
            
            # Copy new version
            Copy-Item -Path $source -Destination $dest -Recurse -Force
            
            Write-Host "SUCCESS" -ForegroundColor Green
            $deployed++
        }
        catch {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "  Error: $_" -ForegroundColor Red
            $failed++
        }
    }
    else {
        Write-Host "SKIPPED $class (not found)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deployed: $deployed plugins" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "Failed: $failed plugins" -ForegroundColor Red
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart Sylvanas loader or press F5 to reload Lua" -ForegroundColor White
Write-Host "2. Check Sylvanas console for plugin load messages" -ForegroundColor White
