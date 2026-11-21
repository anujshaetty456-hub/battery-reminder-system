# Battery Full Alert Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An offline Windows background script that watches battery charge and pops a native notification (with sound) when the laptop is full and still plugged in, auto-starting at every logon with no manual steps.

**Architecture:** A PowerShell script polls `Win32_Battery` via WMI every 60 seconds. When charge ≥ threshold AND AC power is connected, it fires a Windows toast notification (via the `BurntToast` module if present, else a `System.Windows.Forms.NotifyIcon` balloon fallback) plus a notification sound, then suppresses repeat alerts until the charge drops back below the threshold (so it fires once per "became full" event, not every 60s). A second installer script registers a Windows Task Scheduler task that launches this script hidden, at user logon, with restart-on-failure.

**Tech Stack:** Windows PowerShell 5.1 (built-in, no installs required), WMI (`Win32_Battery`), Windows Task Scheduler (`schtasks`/`Register-ScheduledTask`), optional `BurntToast` module with a Forms-balloon fallback so it works fully offline even without that module.

**Spec:** Derived from conversation (no separate spec file) — see Goal above and Global Constraints below for the pinned values.

## Global Constraints

- Must run **fully offline** — no network calls, no package downloads at runtime.
- Must **auto-start on every PC boot/login** with zero manual steps after installation.
- Must **not duplicate** the existing low-battery reminder system — this only handles the "full" case.
- Alert threshold: **95%** charge (configurable constant in the script).
- Alert style: **toast notification + notification sound**.
- Must **not spam**: one alert per full-charge event; resets only after charge drops below threshold again.
- Only alert while **actually plugged in** (AC power connected) — not just "battery happens to read 95%" on battery power.

## Review Focus

- **Laptop has no battery / desktop WMI returns no `Win32_Battery` instance** — script should exit quietly instead of crashing or looping on errors.
- **User unplugs right at the moment of alert** — alert should still show (state already captured before action), and the "already alerted" flag should correctly reset once charge later drops below threshold.
- **PC sleeps/hibernates while script is running** — scheduled task and script must tolerate being frozen and resumed without erroring (stateless polling loop handles this naturally; no explicit task needed beyond using a simple `while` loop with `Start-Sleep`).
- **BurntToast module not installed and not installable offline** — fallback path (NotifyIcon balloon) must be used automatically, not fail silently.
- **Script already running (e.g., user logs off/on repeatedly, multiple triggers)** — installer should ensure only one instance via Task Scheduler's existing-instance policy, not duplicate background processes.

---

## File Structure

- Create: `BatteryFullAlert.ps1` — the monitoring loop (poll, detect full+plugged-in, alert once per event).
- Create: `Install-BatteryFullAlert.ps1` — registers the Task Scheduler task pointing at `BatteryFullAlert.ps1`, run once by the user (with elevation if needed).
- Create: `Uninstall-BatteryFullAlert.ps1` — removes the scheduled task (for completeness/reversibility).

### Task 1: Core monitoring script

**Files:**
- Create: `BatteryFullAlert.ps1`

**Interfaces:**
- Produces: a standalone script with no parameters, runnable via `powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File BatteryFullAlert.ps1`. No other task consumes its internals, but the Task 2 installer references this exact filename and path convention.

- [ ] **Step 1: Write `Get-BatteryStatus` function**

Signature: `function Get-BatteryStatus { }` returning a `PSCustomObject` with `[int]ChargePercent` and `[bool]IsPluggedIn`, read from `Get-CimInstance -ClassName Win32_Battery`. `BatteryStatus` property values 1 ("Discharging") mean not plugged in; 2 ("On AC") and other charging-related codes mean plugged in. If no battery instance exists, return `$null`.

- [ ] **Step 2: Write `Show-FullBatteryAlert` function**

Signature: `function Show-FullBatteryAlert { }`. Body: try loading `BurntToast` (`Get-Module -ListAvailable -Name BurntToast`); if present, call `New-BurntToastNotification` with title `"Battery Full"` and text `"Unplug the charger — your battery is full."`. If not present, fall back to a `System.Windows.Forms.NotifyIcon` with `BalloonTipTitle`/`BalloonTipText` set to the same strings, `Icon` set to a system icon, `ShowBalloonTip(10000)`. After showing either, play a system sound: `[System.Media.SystemSounds]::Exclamation.Play()`.

- [ ] **Step 3: Write the main polling loop**

Constants at top of file: `$ThresholdPercent = 95`, `$PollIntervalSeconds = 60`. Loop body (`while ($true) { ... ; Start-Sleep -Seconds $PollIntervalSeconds }`):
1. Call `Get-BatteryStatus`. If `$null`, `Start-Sleep` and `continue` (no battery present — desktop PC).
2. If `ChargePercent -ge $ThresholdPercent -and $IsPluggedIn -and -not $alreadyAlerted`: call `Show-FullBatteryAlert`, set `$alreadyAlerted = $true`.
3. If `ChargePercent -lt $ThresholdPercent`: set `$alreadyAlerted = $false`.
4. `$alreadyAlerted` initialized to `$false` before the loop starts.

- [ ] **Step 4: Manual verification — run the script directly**

Run: `powershell.exe -ExecutionPolicy Bypass -File BatteryFullAlert.ps1` while plugged in with charge already above 95% (or temporarily lower `$ThresholdPercent` to current charge level to force it).
Expected: a toast or balloon notification appears within one poll interval, with a sound; it does not repeat on the next poll; unplugging and replugging (or dropping below threshold) re-arms it.

- [ ] **Step 5: Commit**

No git repo in this workspace — skip commit; save file as the deliverable.

### Task 2: Autostart installer

**Files:**
- Create: `Install-BatteryFullAlert.ps1`
- Create: `Uninstall-BatteryFullAlert.ps1`

**Interfaces:**
- Consumes: the exact path to `BatteryFullAlert.ps1` produced by Task 1 (same directory, resolved via `$PSScriptRoot`).
- Produces: a Task Scheduler task named `BatteryFullAlert` that any later maintenance (or the uninstaller) references by that exact name.

- [ ] **Step 1: Write `Install-BatteryFullAlert.ps1`**

Body: build the script path as `Join-Path $PSScriptRoot 'BatteryFullAlert.ps1'`. Define:
- `$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""`
- `$trigger = New-ScheduledTaskTrigger -AtLogOn`
- `$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)`
- `$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive`
- Register with `Register-ScheduledTask -TaskName 'BatteryFullAlert' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force`
Print a confirmation message naming the task and that it will run at next logon (and immediately if started manually via `Start-ScheduledTask -TaskName 'BatteryFullAlert'`).

- [ ] **Step 2: Write `Uninstall-BatteryFullAlert.ps1`**

Body: `Unregister-ScheduledTask -TaskName 'BatteryFullAlert' -Confirm:$false` wrapped in a check via `Get-ScheduledTask -TaskName 'BatteryFullAlert' -ErrorAction SilentlyContinue` so it doesn't error if already removed. Print confirmation either way.

- [ ] **Step 3: Manual verification — install and confirm task exists**

Run: `powershell.exe -ExecutionPolicy Bypass -File Install-BatteryFullAlert.ps1`, then `Get-ScheduledTask -TaskName 'BatteryFullAlert'`.
Expected: task listed, `State` is `Ready`, trigger is `AtLogOn`.

- [ ] **Step 4: Manual verification — start it now without rebooting**

Run: `Start-ScheduledTask -TaskName 'BatteryFullAlert'`, then check it's running: `Get-ScheduledTask -TaskName 'BatteryFullAlert' | Select-Object State` should show `Running`.
Expected: no error; script runs hidden in background.

- [ ] **Step 5: Commit**

No git repo in this workspace — skip commit; save files as the deliverable.

## Self-Review Notes

- **Spec coverage:** offline (no network calls anywhere) ✓; autostart at boot/login via Task Scheduler ✓; full-charge alert distinct from existing low-battery system (new task name, doesn't touch any existing settings) ✓; 95% threshold ✓; toast+sound ✓; no-spam/reset logic ✓; plugged-in check ✓.
- **Step scan:** each step names an exact function signature, exact constants, or an exact verification command — no "handle edge cases" placeholders remain.
- **Type consistency:** `Get-BatteryStatus` return shape (`ChargePercent`, `IsPluggedIn`) is used identically in the Task 1 Step 3 loop; no other task touches these names.
- **Review Focus coverage:** no-battery case → Step 1 returns `$null`, Step 3 handles it; unplug-at-alert-moment → state captured before action, flag logic is pure and re-arms on next drop below threshold; sleep/resume → stateless loop with `Start-Sleep` needs no special handling; BurntToast missing → explicit fallback in Step 2; duplicate instances → Task Scheduler's default behavior for an `AtLogOn` trigger with one task registration avoids duplicate scheduled triggers (noted as accepted default rather than an extra `-MultipleInstances` setting, since logon fires once per session).
- **Proportion:** plan is a few hundred lines against an estimated ~80-line total script output — proportionate for two small files with an installer.
