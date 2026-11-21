# bootstrap.ps1 - one-command installer for viewers.
# Downloads the repo as a zip (no git required), extracts it, runs Install.ps1,
# then cleans up the temp files. This is the file viewers' one-liner fetches
# and runs directly - it does not need to be cloned first.

$ErrorActionPreference = 'Stop'
$RepoZipUrl = 'https://github.com/anujshaetty456-hub/battery-reminder-system/archive/refs/heads/main.zip'
$TempRoot   = Join-Path $env:TEMP 'BatteryMonitorSetup'
$ZipPath    = Join-Path $TempRoot 'repo.zip'
$ExtractDir = Join-Path $TempRoot 'extracted'

Write-Host "Downloading Battery Alerts..." -ForegroundColor Cyan

if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

try {
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $ZipPath -UseBasicParsing
} catch {
    Write-Host "ERROR: Could not download the installer." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)"
    exit 1
}

Write-Host "Extracting..." -ForegroundColor Cyan
try {
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force
} catch {
    Write-Host "ERROR: Could not extract the downloaded files." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)"
    exit 1
}

# The zip extracts into a subfolder named "battery-reminder-system-main".
$ProjectDir = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1 -ExpandProperty FullName

if (-not $ProjectDir -or -not (Test-Path (Join-Path $ProjectDir 'Install.ps1'))) {
    Write-Host "ERROR: Downloaded files don't look right (Install.ps1 not found)." -ForegroundColor Red
    exit 1
}

Write-Host "Installing..." -ForegroundColor Cyan
& (Join-Path $ProjectDir 'Install.ps1')

# Clean up the temp download/extract folder. Install.ps1 already copied the
# real files into their permanent home (%LOCALAPPDATA%\BatteryMonitor), so
# this temp folder is safe to delete right after.
Start-Sleep -Seconds 1
Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
