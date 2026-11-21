# Install.ps1 - one-click installer for BatteryMonitor
# Double-click Install.bat (or run this) to install.
# No admin rights required: uses the Windows Startup folder, which starts
# the monitor hidden every time you log in. Falls back to Task Scheduler
# only if a Task Scheduler entry already exists from a previous install.

$ErrorActionPreference = 'Stop'
$ScriptPath = Join-Path $PSScriptRoot 'BatteryMonitor.ps1'
$TaskName = 'BatteryMonitor'

if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERROR: Could not find BatteryMonitor.ps1 next to this installer." -ForegroundColor Red
    Write-Host "Make sure all the files are in the same folder, then try again."
    exit 1
}

# Clean up any old Task Scheduler entry from a previous install attempt (ignore if none / no permission).
try {
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue }
} catch {}

$StartupFolder = [Environment]::GetFolderPath('Startup')
$ShortcutPath = Join-Path $StartupFolder 'BatteryMonitor.lnk'

try {
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.WindowStyle = 7   # minimized
    $shortcut.Description = 'BatteryMonitor - offline battery alert monitor'
    $shortcut.Save()
} catch {
    Write-Host "ERROR: Could not create the startup shortcut." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)"
    exit 1
}

if (-not (Test-Path $ShortcutPath)) {
    Write-Host "ERROR: Shortcut was not created. Installation failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installed. BatteryMonitor will start automatically every time you log in." -ForegroundColor Green
Write-Host "Starting it now so it's already protecting your battery..."

try {
    Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`"" `
        -WindowStyle Hidden
    Start-Sleep -Seconds 1
    Write-Host "Started." -ForegroundColor Green
} catch {
    Write-Host "Could not start it immediately, but it will start next time you log in." -ForegroundColor Yellow
    Write-Host "Details: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Done. You can close this window."
