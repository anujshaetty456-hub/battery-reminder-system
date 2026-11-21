# Battery Alerts

An offline Windows battery monitor that alerts you — with a real popup and
sound — when your laptop is **full** (unplug it), at **~30%** (plug in
soon), or **low** (15% or below — urgent). All three alerts keep repeating
on their own schedule until you fix the problem, then stop automatically.

No internet, no accounts, no admin rights, no third-party installs. Runs
entirely on built-in Windows PowerShell and WMI.

## Install (one command)

Clone the repo, then run this from inside it:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

That's the whole setup. It:
- Registers `BatteryMonitor.ps1` to start automatically, hidden, every time you log in (via your Windows Startup folder — no admin rights needed).
- Starts it immediately, so it's already protecting your battery.

Or just double-click `Install.bat` instead of running the command above.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Or double-click `Uninstall.bat`.

## Changing alert thresholds / repeat timing

Open `BatteryMonitor.ps1` in any text editor. Everything you'd want to
change is in the clearly labeled `CONFIG` block at the top of the file:

```powershell
$FullThreshold    = 95     # % charge, while plugged in -> "unplug" alert
$MidThreshold     = 30     # % charge, while unplugged  -> "plug in soon" alert
$LowThreshold     = 15     # % charge, while unplugged  -> urgent repeating alert
$PollIntervalSec  = 60     # how often to check battery state
$FullRepeatSec    = 120    # how often the FULL alert re-fires until unplugged
$MidRepeatSec     = 300    # how often the MID (~30%) alert re-fires until plugged in
$LowRepeatSec     = 120    # how often the LOW alert re-fires until plugged in
```

Save, then re-run `Install.ps1` (or restart your PC) for changes to take effect.

## Files

| File | Purpose |
|---|---|
| `BatteryMonitor.ps1` | The monitor itself — polls battery state, fires alerts, logs activity, self-restarts on crash |
| `Install.ps1` / `Install.bat` | One-command installer — registers autostart and starts the monitor |
| `Uninstall.ps1` / `Uninstall.bat` | One-command uninstaller |
| `READ ME - Battery Alerts.txt` | Plain-English guide for non-technical use |
| `docs/TEST-REPORT.md` | Full test report: what was tested, how, and the result |

## How it works

- Checks battery charge % and plugged-in state every 60 seconds via `Get-CimInstance Win32_Battery`.
- Shows a real Windows toast notification (WinRT) plus a `.wav` sound for each alert.
- Logs every check and alert to `BatteryMonitor.log` next to the script.
- If it ever crashes, it logs the error, waits 5 seconds, and relaunches itself automatically.
- Starts via a shortcut in your Windows Startup folder — no scheduled task, no admin rights.

## Requirements

- Windows 10/11
- PowerShell 5.1 (built into Windows — nothing to install)
