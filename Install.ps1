# Install.ps1 - one-click installer for BatteryMonitor
# Double-click Install.bat (or run this) to install.
#
# Copies BatteryMonitor.ps1 into a permanent, stable folder
# (%LOCALAPPDATA%\BatteryMonitor) and registers autostart to point THERE,
# not at wherever you happen to be running this installer from. That way,
# autostart keeps working even if you later move, delete, or clean up the
# folder you downloaded/cloned this installer into.
#
# No admin rights required: uses the Windows Startup folder, which starts
# the monitor hidden every time you log in.

$ErrorActionPreference = 'Stop'
$SourceScriptPath = Join-Path $PSScriptRoot 'BatteryMonitor.ps1'
$TaskName = 'BatteryMonitor'

if (-not (Test-Path $SourceScriptPath)) {
    Write-Host "ERROR: Could not find BatteryMonitor.ps1 next to this installer." -ForegroundColor Red
    Write-Host "Make sure all the files are in the same folder, then try again."
    exit 1
}

# --- Stop any already-running copy first (old or new install location), so
#     re-installing never leaves two instances running at once. ---
try {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*BatteryMonitor.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

# --- Copy the real files into a permanent, stable install folder. ---
$InstallDir = Join-Path $env:LOCALAPPDATA 'BatteryMonitor'
try {
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    Copy-Item -Path $SourceScriptPath -Destination (Join-Path $InstallDir 'BatteryMonitor.ps1') -Force
} catch {
    Write-Host "ERROR: Could not copy BatteryMonitor.ps1 to the install folder." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)"
    exit 1
}
$ScriptPath = Join-Path $InstallDir 'BatteryMonitor.ps1'

# --- Clean up any old Task Scheduler entry from a previous install attempt. ---
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
    $shortcut.WorkingDirectory = $InstallDir
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
Write-Host "Installed to: $InstallDir" -ForegroundColor Green
Write-Host "BatteryMonitor will start automatically every time you log in - even if you" -ForegroundColor Green
Write-Host "later delete or move the folder you ran this installer from." -ForegroundColor Green
Write-Host ""
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
