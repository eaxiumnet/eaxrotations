param(
    [string]$Version = "1.1.1",
    [string]$Modified = "2026-05-27",
    [string]$Change = "File version stamp for runtime load verification"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$frameworkFiles = @(
    "header.lua",
    "core_sylvanas.lua",
    "main_sylvanas.lua"
)

function Get-RelativeLuaPath {
    param([System.IO.FileInfo]$File)

    $relative = [System.IO.Path]::GetRelativePath($root.Path, $File.FullName)
    return ($relative -replace "\\", "/")
}

function New-VersionHeader {
    param([string]$RelativePath)

    return @"
-- =========================================================================`n-- EaxRotations File Version: $Version`n-- Last Modified: $Modified`n-- Change: $Change`n-- =========================================================================`nlocal __eax_file = "$RelativePath"`nlocal __eax_version = "$Version"`nlocal __eax_modified = "$Modified"`nlocal __eax_change = "$Change"`nlocal __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}`n_G.EaxRotationsFileVersions = __eax_versions`n__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }`nlocal __eax_core = rawget(_G, "core")`nif type(__eax_core) == "table" and type(__eax_core.log) == "function" then`n    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)`nend`nlocal __eax_ns = rawget(_G, "EaxRotations")`nif type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end`n
"@
}

function Add-FrameworkLoadedLog {
    param(
        [string]$Content,
        [string]$FileName
    )

    $legacyLogLine = "core.log(`"[EaxRotations] Loaded $FileName v$Version`")"
    $safeLogLine = "if type(core) == `"table`" and type(core.log) == `"function`" then pcall(core.log, `"[EaxRotations] Loaded $FileName v$Version`") end"
    if ($Content.Contains($safeLogLine)) {
        return $Content
    }

    if ($Content.Contains($legacyLogLine)) {
        return $Content.Replace($legacyLogLine, $safeLogLine)
    }

    $escapedReturn = [regex]::Escape("return")
    $pattern = "(?m)^(\s*)$escapedReturn\b(.*)$"
    $match = [regex]::Match($Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::RightToLeft)
    if (-not $match.Success) {
        return $Content.TrimEnd() + "`n" + $safeLogLine + "`n"
    }

    $insert = $match.Groups[1].Value + $safeLogLine + "`n" + $match.Value
    return $Content.Substring(0, $match.Index) + $insert + $Content.Substring($match.Index + $match.Length)
}

$luaFiles = Get-ChildItem -LiteralPath $root.Path -Recurse -File -Filter "*.lua" | Sort-Object FullName
$stamped = 0
$skipped = 0
$frameworkLogged = 0

foreach ($file in $luaFiles) {
    $relative = Get-RelativeLuaPath -File $file
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $original = $content

    if ($content -match "(?m)^-- EaxRotations File Version:") {
        $skipped++
    } else {
        $content = (New-VersionHeader -RelativePath $relative) + $content
        $stamped++
    }

    if ($frameworkFiles -contains $relative) {
        $content = Add-FrameworkLoadedLog -Content $content -FileName $relative
        if ($content -ne $original) { $frameworkLogged++ }
    }

    if ($content -ne $original) {
        Set-Content -LiteralPath $file.FullName -Value $content -NoNewline -Encoding UTF8
    }
}

Write-Host "Stamped $stamped Lua files; skipped $skipped already stamped files; framework logs checked: $frameworkLogged."
