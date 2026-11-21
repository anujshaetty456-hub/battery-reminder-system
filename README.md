# Battery Alerts

An offline Windows battery monitor that alerts you — with a real popup and
sound — when your laptop is **full** (unplug it), at **~30%** (plug in
soon), or **low** (15% or below — urgent). All three alerts keep repeating
on their own schedule until you fix the problem, then stop automatically.

No internet, no accounts, no admin rights, no third-party installs. Runs
entirely on built-in Windows PowerShell and WMI.

## Install — one command, nothing to download first

Open PowerShell and paste this:

```powershell
irm https://raw.githubusercontent.com/anujshaetty456-hub/battery-reminder-system/main/bootstrap.ps1 | iex
```

That's it. This one line downloads everything, installs it, and starts
protecting your battery immediately — no git, no manual download, no
unzipping. You don't need to clone this repo first.

What it does:
- Downloads this repo, installs `BatteryMonitor.ps1` into a permanent folder on your PC.
- Registers it to start automatically, hidden, every time you log in (via your Windows Startup folder — no admin rights needed).
- Starts it immediately.
- Cleans up the temporary download files afterward.

### Alternative: clone it yourself

If you'd rather see the code first:

```powershell
git clone https://github.com/anujshaetty456-hub/battery-reminder-system.git
cd battery-reminder-system
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

Or just double-click `Install.bat` after cloning.

### Is the one-line install safe?

`irm ... | iex` downloads and runs a script directly, so you should only
do this for scripts you trust. This repo is fully open source — read
[`bootstrap.ps1`](bootstrap.ps1) and [`Install.ps1`](Install.ps1) yourself
before running them if you want to verify exactly what they do. Neither
one sends anything over the network, asks for admin rights, or touches
anything outside this app's own folder.

## Uninstall

One line, no clone needed:

```powershell
irm https://raw.githubusercontent.com/anujshaetty456-hub/battery-reminder-system/main/Uninstall.ps1 | iex
```

Or, if you cloned the repo:

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
| `bootstrap.ps1` | What the one-line `irm \| iex` command runs — downloads the repo and installs it, no clone needed |
| `BatteryMonitor.ps1` | The monitor itself — polls battery state, fires alerts, logs activity, self-restarts on crash |
| `Install.ps1` / `Install.bat` | Installer used after cloning — registers autostart and starts the monitor |
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
