# build_eaxrotations_zip.ps1 — produce clean eaxrotations.zip (lua + md only)
# WHAT:  Stage EaxRotations/*.lua + *.md into a zip with EaxRotations/ at archive root.
# WHEN:  Release pipeline / manual release packaging.
# WHY:  Plugin consumers must not receive tests data, binaries, or non-plugin assets.
# USAGE: pwsh build_tools/build_eaxrotations_zip.ps1
# OUTPUT: ./eaxrotations.zip (overwrite)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'EaxRotations'))) {
    $root = (Get-Location).Path
}
$src = Join-Path $root 'EaxRotations'
$stage = Join-Path $root '_release_stage_eax'
$zipPath = Join-Path $root 'eaxrotations.zip'

if (-not (Test-Path $src)) {
    throw "EaxRotations folder not found at $src"
}

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
$destRoot = Join-Path $stage 'EaxRotations'
New-Item -ItemType Directory -Path $destRoot -Force | Out-Null

Get-ChildItem -Path $src -Recurse -File |
    Where-Object { $_.Extension -in '.lua', '.md' } |
    ForEach-Object {
        $rel = $_.FullName.Substring($src.Length + 1)
        $out = Join-Path $destRoot $rel
        $dir = Split-Path $out -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -LiteralPath $_.FullName -Destination $out -Force
    }

if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stage,
    $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)

$z = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $count = $z.Entries.Count
    $bad = @($z.Entries | Where-Object {
        $e = [IO.Path]::GetExtension($_.FullName).ToLowerInvariant()
        $e -and $e -notin '.lua', '.md'
    })
    if ($bad.Count -gt 0) {
        throw "Zip contains non lua/md files: $($bad[0].FullName)"
    }
    $size = (Get-Item $zipPath).Length
    Write-Host "Built $zipPath ($count entries, $size bytes) — lua+md only, root=EaxRotations/"
}
finally {
    $z.Dispose()
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
}
