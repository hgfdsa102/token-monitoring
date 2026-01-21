# TokenMonitorMenuBar Spec

## Overview
- macOS menu bar app that shows Claude Code usage percent and time remaining until reset.
- Data source is the Claude Code interactive `/status` UI captured via a PTY session (no ccusage usage).

## Data Capture
- Script: `capture-status.py`
- Launches `claude` in a pseudo-terminal, types `/status`, switches to Usage tab (Tab), parses text.
- Output:
  - JSON summary when `--json` is passed.
  - Optional raw output file when `--raw <path>` is passed.
- JSON fields used by the app:
  - `current_session_percent` (int)
  - `current_session_reset` (string)

## Menu Bar App
- Project: `mac-app/TokenMonitorMenuBar/TokenMonitorMenuBar.xcodeproj`
- Executable: `TokenMonitorMenuBar.app`
- Menu bar only (LSUIElement enabled for normal use).
- Status item text format:
  - With percent: `<percent>%|<HH:MM>`
  - Without percent: `<HH:MM>`

## Countdown Behavior
- Countdown is derived from the last parsed reset time and updated every minute.
- If the countdown reaches 0, the next reset is assumed to be 5 hours later (fixed 5-hour cycle).
- If `/status` is refreshed, the countdown is re-synced to the newly parsed reset time.

## Refresh Behavior
- Background refresh re-runs `/status` on a selectable interval:
  - 10 min, 30 min, 1 hour
- Menu action: `Refresh Now` triggers immediate refresh.
- Countdown is updated every 60 seconds independently of refresh.

## Menu
- `Refresh Now`
- `Refresh Interval` submenu (10 min / 30 min / 1 hour)
- `Quit`

## Logging
- Log file: `~/Library/Logs/TokenMonitorMenuBar.log`
- Logs app lifecycle, refresh events, capture script start/finish, and parse failures.

## Environment Variables
- `TOKEN_MONITOR_DEBUG=1` : uses regular activation policy for debugging.
- `TOKEN_MONITOR_FORCE_REGULAR=1` : forces regular activation policy.
- `TOKEN_MONITOR_LOG_PATH=<path>` : overrides log file location.
- `TOKEN_MONITOR_CAPTURE_PATH=<path>` : overrides capture script path.
- `TOKEN_MONITOR_CAPTURE_RAW=<path>` : writes raw `/status` output to file.

## Scripts
- `check-claude-usage.sh --json` : convenience wrapper around `capture-status.py`.

## Assumptions
- Claude Code usage reset cycle is 5 hours.
- `/status` output contains a "Resets" line for current session usage.
