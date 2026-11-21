# Uninstall.ps1 - one-click uninstaller for BatteryMonitor
# Removes the Startup shortcut (and any leftover Task Scheduler entry), and stops it if running.

$TaskName = 'BatteryMonitor'
$StartupFolder = [Environment]::GetFolderPath('Startup')
$ShortcutPath = Join-Path $StartupFolder 'BatteryMonitor.lnk'
$removedSomething = $false

if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
    Write-Host "Removed startup entry." -ForegroundColor Green
    $removedSomething = $true
}

try {
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed scheduled task." -ForegroundColor Green
        $removedSomething = $true
    }
} catch {}

if (-not $removedSomething) {
    Write-Host "BatteryMonitor was not installed (nothing to remove)." -ForegroundColor Yellow
}

# Stop any currently-running copy of the monitor script.
try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*BatteryMonitor.ps1*' } |
        ForEach-Object {
            try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
        }
} catch {}

Write-Host ""
Write-Host "BatteryMonitor will not start again. Done. You can close this window."
