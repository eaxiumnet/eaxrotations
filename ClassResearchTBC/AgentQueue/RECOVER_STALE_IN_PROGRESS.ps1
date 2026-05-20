param(
    [int]$StaleMinutes = 30,
    [switch]$WhatIfOnly
)

# Moves stale AgentQueue in_progress jobs back to pending.
# This is local recovery for timed-out/free sessions; it does not interact with any external queue.

$queueRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$inProgress = Join-Path $queueRoot "in_progress"
$pending = Join-Path $queueRoot "pending"
$manifest = Join-Path $queueRoot "MANIFEST.md"
$now = Get-Date

if (-not (Test-Path -LiteralPath $inProgress)) {
    throw "Missing in_progress folder: $inProgress"
}

if (-not (Test-Path -LiteralPath $pending)) {
    throw "Missing pending folder: $pending"
}

function Get-HeartbeatTime {
    param([string]$Path)

    $line = Select-String -LiteralPath $Path -Pattern '^Heartbeat:\s*(.+)$' | Select-Object -Last 1
    if (-not $line) {
        return $null
    }

    $raw = $line.Matches[0].Groups[1].Value.Trim()
    $parsed = $null
    if ([DateTime]::TryParse($raw, [ref]$parsed)) {
        return $parsed
    }

    return $null
}

$jobs = Get-ChildItem -LiteralPath $inProgress -Filter "*.md" -File | Sort-Object LastWriteTime
$moved = @()

foreach ($job in $jobs) {
    $heartbeat = Get-HeartbeatTime -Path $job.FullName
    $ageBase = if ($heartbeat) { $heartbeat } else { $job.LastWriteTime }
    $ageMinutes = ($now - $ageBase).TotalMinutes

    if ($ageMinutes -lt $StaleMinutes) {
        Write-Host "Fresh: $($job.Name) age=$([math]::Round($ageMinutes, 1))m"
        continue
    }

    $target = Join-Path $pending $job.Name
    if (Test-Path -LiteralPath $target) {
        $stamp = $now.ToString("yyyyMMdd_HHmmss")
        $base = [IO.Path]::GetFileNameWithoutExtension($job.Name)
        $target = Join-Path $pending ("{0}_recovered_{1}.md" -f $base, $stamp)
    }

    if ($WhatIfOnly) {
        Write-Host "Would recover stale job: $($job.Name) -> $(Split-Path -Leaf $target)"
    } else {
        Write-Host "Recovering stale job: $($job.Name) -> $(Split-Path -Leaf $target)"
    }

    if (-not $WhatIfOnly) {
        $text = Get-Content -LiteralPath $job.FullName -Raw
        $note = @"

## Recovery - $($now.ToString("yyyy-MM-dd HH:mm"))

Moved from `in_progress` back to `pending` by `RECOVER_STALE_IN_PROGRESS.ps1` after $([math]::Round($ageMinutes, 1)) minutes without heartbeat.
"@
        $text = $text -replace '(?m)^Status:\s*in_progress\s*$', 'Status: pending'
        $text = $text + $note
        Set-Content -LiteralPath $job.FullName -Value $text -Encoding UTF8
        Move-Item -LiteralPath $job.FullName -Destination $target
        $moved += (Split-Path -Leaf $target)
    }
}

if (-not $WhatIfOnly -and $moved.Count -gt 0 -and (Test-Path -LiteralPath $manifest)) {
    $manifestText = Get-Content -LiteralPath $manifest -Raw
    foreach ($name in $moved) {
        $manifestText = $manifestText -replace "(\| $([regex]::Escape($name)) \| [^|]+ \| )in_progress(\s*\|)", '${1}pending${2}'
    }
    Add-Content -LiteralPath $manifest -Value ("`nRecovery run {0}: moved {1} stale job(s): {2}" -f $now.ToString("yyyy-MM-dd HH:mm"), $moved.Count, ($moved -join ", "))
}

Write-Host "Recovered stale jobs: $($moved.Count)"
