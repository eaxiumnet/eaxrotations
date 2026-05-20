param(
    [string]$PromptFile = ".\LLM_IMPLEMENTATION_PROMPTS_29.md",
    [int]$IntervalSeconds = 300,
    [int]$ClickIntervalSeconds = 1
)

# Pastes prompts from LLM_IMPLEMENTATION_PROMPTS_29.md into the active window.
# Toggle sending with G. Stop the script with Ctrl+C.
# Sends every 5 minutes by default and restarts from prompt 1 after prompt 29.

Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class PromptSenderNative {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@

$VK_G = 0x47
$MOUSEEVENTF_LEFTDOWN = 0x0002
$MOUSEEVENTF_LEFTUP = 0x0004

if (-not (Test-Path -LiteralPath $PromptFile)) {
    throw "Prompt file not found: $PromptFile"
}

$content = Get-Content -LiteralPath $PromptFile -Raw
$matches = [regex]::Matches($content, '(?ms)^```text\s*(.*?)\s*^```')

if ($matches.Count -eq 0) {
    throw "No ```text prompt blocks found in: $PromptFile"
}

$prompts = @()
foreach ($match in $matches) {
    $prompt = $match.Groups[1].Value.Trim()
    if ($prompt.Length -gt 0) {
        $prompts += $prompt
    }
}

if ($prompts.Count -eq 0) {
    throw "Prompt blocks were found, but all were empty: $PromptFile"
}

$enabled = $false
$lastGDown = $false
$index = 0
$lastSend = (Get-Date).AddSeconds(-$IntervalSeconds)
$lastClick = Get-Date

Write-Host "Prompt sender ready."
Write-Host "Loaded prompts: $($prompts.Count)"
Write-Host "Prompt file: $PromptFile"
Write-Host "Interval: $IntervalSeconds seconds"
Write-Host "Left-click interval: $ClickIntervalSeconds second(s)"
Write-Host "Press G to toggle sending ON/OFF. Ctrl+C exits."
Write-Host "Status: OFF"

while ($true) {
    $gDown = ([PromptSenderNative]::GetAsyncKeyState($VK_G) -band 0x8000) -ne 0

    if ($gDown -and -not $lastGDown) {
        $enabled = -not $enabled
        if ($enabled) {
            Write-Host "Status: ON"
            $lastSend = (Get-Date).AddSeconds(-$IntervalSeconds)
        } else {
            Write-Host "Status: OFF"
        }
    }

    $lastGDown = $gDown

    if ($enabled -and ((Get-Date) - $lastClick).TotalSeconds -ge $ClickIntervalSeconds) {
        [PromptSenderNative]::mouse_event($MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 30
        [PromptSenderNative]::mouse_event($MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
        $lastClick = Get-Date
    }

    if ($enabled -and ((Get-Date) - $lastSend).TotalSeconds -ge $IntervalSeconds) {
        if ($index -ge $prompts.Count) {
            $index = 0
            Write-Host "Restarting from prompt 1."
        }

        $promptNumber = $index + 1
        Write-Host "Sending prompt $promptNumber / $($prompts.Count)"

        [System.Windows.Forms.Clipboard]::SetText($prompts[$index])
        Start-Sleep -Milliseconds 150
        [System.Windows.Forms.SendKeys]::SendWait("^v")
        Start-Sleep -Milliseconds 150
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

        $index++
        $lastSend = Get-Date
    }

    Start-Sleep -Milliseconds 25
}
