# BatteryMonitor.ps1
# Offline battery alert monitor: Full / 30% / Low. No internet, no installs.
# Runs forever in a loop; meant to be launched hidden by Install.ps1's scheduled task.

# =========================== CONFIG (edit these) ===========================
$FullThreshold    = 95     # % charge, while plugged in -> "unplug" alert
$MidThreshold     = 30     # % charge, while unplugged  -> "plug in soon" alert
$LowThreshold     = 15     # % charge, while unplugged  -> urgent repeating alert
$PollIntervalSec  = 60     # how often to check battery state
$FullRepeatSec    = 120    # how often the FULL alert re-fires until unplugged
$MidRepeatSec     = 300    # how often the MID (~30%) alert re-fires until plugged in
$LowRepeatSec     = 120    # how often the LOW alert re-fires until plugged in
$LogPath          = Join-Path $PSScriptRoot 'BatteryMonitor.log'
$LogMaxBytes      = 1MB    # trim log when it exceeds this size
# =============================================================================
# All three alerts (Full, ~30%, Low) now REPEAT on their interval above for as
# long as the condition stays true, not just once. They stop repeating only
# when the condition is resolved (charger unplugged after Full, or plugged in
# after Mid/Low).

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message)
    try {
        if ((Test-Path $LogPath) -and (Get-Item $LogPath).Length -gt $LogMaxBytes) {
            $keep = Get-Content $LogPath -Tail 200
            Set-Content -Path $LogPath -Value $keep
        }
        $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
        Add-Content -Path $LogPath -Value $line
    } catch {
        # Logging must never crash the monitor.
    }
}

function Get-BatteryStatus {
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop | Select-Object -First 1
        if (-not $battery) { return $null }

        # BatteryStatus: 1 = Discharging (on battery), 2 = On AC/Charging, others = various AC-connected states.
        $pluggedIn = $battery.BatteryStatus -ne 1

        return [PSCustomObject]@{
            ChargePercent = [int]$battery.EstimatedChargeRemaining
            IsPluggedIn   = $pluggedIn
        }
    } catch {
        Write-Log "ERROR reading battery status: $($_.Exception.Message)"
        return $null
    }
}

$ToastAppId = 'Microsoft.Windows.Explorer'
$NormalSoundPath = "$env:WINDIR\Media\Windows Notify System Generic.wav"
$UrgentSoundPath = "$env:WINDIR\Media\Windows Battery Critical.wav"

function Show-ToastPopup {
    param([string]$Title, [string]$Text)
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $escTitle = [System.Security.SecurityElement]::Escape($Title)
        $escText  = [System.Security.SecurityElement]::Escape($Text)
        $template = "<toast><visual><binding template=`"ToastGeneric`"><text>$escTitle</text><text>$escText</text></binding></visual></toast>"

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($ToastAppId).Show($toast)
        return $true
    } catch {
        Write-Log "Toast notification failed: $($_.Exception.Message)"
        return $false
    }
}

function Play-AlertSound {
    param([string]$SoundPath)
    try {
        if (-not (Test-Path $SoundPath)) { $SoundPath = "$env:WINDIR\Media\notify.wav" }
        $player = New-Object System.Media.SoundPlayer $SoundPath
        $player.PlaySync()
        return $true
    } catch {
        Write-Log "Sound playback failed: $($_.Exception.Message)"
        try { [System.Media.SystemSounds]::Exclamation.Play(); return $true } catch { return $false }
    }
}

function Show-Notification {
    param(
        [string]$Title,
        [string]$Text,
        [switch]$Urgent
    )
    $shown = Show-ToastPopup -Title $Title -Text $Text

    if (-not $shown) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
            $icon = New-Object System.Windows.Forms.NotifyIcon
            $icon.Icon = [System.Drawing.SystemIcons]::Information
            $icon.BalloonTipTitle = $Title
            $icon.BalloonTipText = $Text
            $icon.Visible = $true
            $icon.ShowBalloonTip(10000)
            Start-Sleep -Seconds 1
            $icon.Dispose()
            $shown = $true
        } catch {
            Write-Log "Balloon notification fallback failed: $($_.Exception.Message)"
        }
    }

    if ($Urgent) {
        Play-AlertSound -SoundPath $UrgentSoundPath
    } else {
        Play-AlertSound -SoundPath $NormalSoundPath
    }

    return $shown
}

function Start-SelfRestart {
    try {
        $thisScript = $PSCommandPath
        Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$thisScript`"" `
            -WindowStyle Hidden
        Write-Log "Self-restart launched a fresh copy."
    } catch {
        Write-Log "Self-restart FAILED: $($_.Exception.Message)"
    }
}

function Invoke-MonitorLoop {

$fullAlertFired = $false
$midAlertFired  = $false
$lowAlertFired  = $false
$lastFullAlertTime = Get-Date 0
$lastMidAlertTime  = Get-Date 0
$lastLowAlertTime  = Get-Date 0

while ($true) {
    $status = Get-BatteryStatus

    if ($null -eq $status) {
        # No battery present (desktop) or read failed. Idle quietly.
        Start-Sleep -Seconds $PollIntervalSec
        continue
    }

    $pct = $status.ChargePercent
    $plugged = $status.IsPluggedIn
    $now = Get-Date

    # --- FULL alert: plugged in and at/above threshold. Repeats until unplugged. ---
    if ($plugged -and $pct -ge $FullThreshold) {
        if (-not $fullAlertFired -or (($now - $lastFullAlertTime).TotalSeconds -ge $FullRepeatSec)) {
            $didShow = Show-Notification -Title 'Battery Full' -Text 'Unplug your charger.'
            $fullAlertFired = $true
            $lastFullAlertTime = $now
            Write-Log "pct=$pct plugged=$plugged ALERT=FULL shown=$didShow"
        } else {
            Write-Log "pct=$pct plugged=$plugged state=FULL (waiting for repeat interval)"
        }
    } else {
        if ($fullAlertFired) { Write-Log "pct=$pct plugged=$plugged FULL alert reset" }
        $fullAlertFired = $false
    }

    # --- LOW / MID alerts only make sense while unplugged ---
    if (-not $plugged) {
        # LOW: most urgent, takes priority over MID, repeats until plugged in.
        if ($pct -le $LowThreshold) {
            if (-not $lowAlertFired -or (($now - $lastLowAlertTime).TotalSeconds -ge $LowRepeatSec)) {
                $didShow = Show-Notification -Title 'Battery LOW' -Text 'Plug in NOW.' -Urgent
                $lowAlertFired = $true
                $lastLowAlertTime = $now
                Write-Log "pct=$pct plugged=$plugged ALERT=LOW shown=$didShow"
            } else {
                Write-Log "pct=$pct plugged=$plugged state=LOW (waiting for repeat interval)"
            }
        } else {
            if ($lowAlertFired) { Write-Log "pct=$pct plugged=$plugged LOW alert reset" }
            $lowAlertFired = $false
        }

        # MID (~30%): only when not already in LOW territory. Repeats until plugged in.
        if ($pct -le $MidThreshold -and $pct -gt $LowThreshold) {
            if (-not $midAlertFired -or (($now - $lastMidAlertTime).TotalSeconds -ge $MidRepeatSec)) {
                $didShow = Show-Notification -Title 'Battery at 30%' -Text 'Plug in soon.'
                $midAlertFired = $true
                $lastMidAlertTime = $now
                Write-Log "pct=$pct plugged=$plugged ALERT=MID shown=$didShow"
            } else {
                Write-Log "pct=$pct plugged=$plugged state=MID (waiting for repeat interval)"
            }
        } elseif ($pct -gt $MidThreshold) {
            if ($midAlertFired) { Write-Log "pct=$pct plugged=$plugged MID alert reset" }
            $midAlertFired = $false
        }
    } else {
        # Plugged in: reset both unplugged-only alerts so they re-arm for next time.
        if ($midAlertFired) { Write-Log "pct=$pct plugged=$plugged MID alert reset (plugged in)" }
        if ($lowAlertFired) { Write-Log "pct=$pct plugged=$plugged LOW alert reset (plugged in)" }
        $midAlertFired = $false
        $lowAlertFired = $false
    }

    Start-Sleep -Seconds $PollIntervalSec
}
}

try {
    Write-Log "BatteryMonitor started."
    Invoke-MonitorLoop
} catch {
    Write-Log "FATAL ERROR, monitor crashed: $($_.Exception.Message)"
    Start-Sleep -Seconds 5
    Start-SelfRestart
}
