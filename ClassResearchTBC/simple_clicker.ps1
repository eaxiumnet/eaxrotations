# Simple left-click auto clicker.
# Toggle enabled/disabled with G. Stop the script with Ctrl+C.

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ClickerNative {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@

$VK_G = 0x47
$MOUSEEVENTF_LEFTDOWN = 0x0002
$MOUSEEVENTF_LEFTUP = 0x0004

$enabled = $false
$lastGDown = $false
$lastClick = Get-Date

Write-Host "Simple clicker started. Press G to toggle on/off. Ctrl+C exits."
Write-Host "Status: OFF"

while ($true) {
    $gDown = ([ClickerNative]::GetAsyncKeyState($VK_G) -band 0x8000) -ne 0

    if ($gDown -and -not $lastGDown) {
        $enabled = -not $enabled
        if ($enabled) {
            Write-Host "Status: ON"
            $lastClick = (Get-Date).AddSeconds(-1)
        } else {
            Write-Host "Status: OFF"
        }
    }

    $lastGDown = $gDown

    if ($enabled -and ((Get-Date) - $lastClick).TotalSeconds -ge 1) {
        [ClickerNative]::mouse_event($MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 30
        [ClickerNative]::mouse_event($MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
        $lastClick = Get-Date
    }

    Start-Sleep -Milliseconds 25
}
