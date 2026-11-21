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

# Remove the stable install folder (the copy Install.ps1 made in %LOCALAPPDATA%),
# so nothing is left behind. This is separate from wherever you ran this
# uninstaller from, which is never touched.
$InstallDir = Join-Path $env:LOCALAPPDATA 'BatteryMonitor'
if (Test-Path $InstallDir) {
    try {
        Remove-Item $InstallDir -Recurse -Force -ErrorAction Stop
        Write-Host "Removed installed files from $InstallDir." -ForegroundColor Green
    } catch {
        Write-Host "Could not remove $InstallDir (it may still contain a log file in use)." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "BatteryMonitor will not start again. Done. You can close this window."
