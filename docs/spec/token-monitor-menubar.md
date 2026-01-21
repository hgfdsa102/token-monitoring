# TokenMonitorMenuBar Spec

## Overview
A macOS menu bar app that periodically runs the capture script, parses current session usage, and displays a countdown until reset.

## Components
- `Main.swift` : sets activation policy and runs the app.
- `TokenMonitorMenuBarApp.swift` : status item UI, timers, menus.
- `StatusMonitor.swift` : runs `capture-status.py` and parses JSON.
- `Logger.swift` : file + NSLog logging.

## UI Behavior
- Status bar title format:
  - With percent: `<percent>%|<HH:MM>`
  - Without percent: `--:--` or `<HH:MM>` when available
- Menu items:
  - `Refresh Now`
  - `Refresh Interval` (10 min / 30 min / 1 hour)
  - `Quit`

## Refresh/Countdown
- Refresh timer uses the user-selected interval (default 10 minutes).
- Countdown timer updates every 60 seconds.
- Countdown target uses the last parsed reset time; if the time is in the past, it advances by 5-hour cycles.

## Capture Execution
- Launches `/usr/bin/python3` with `capture-status.py --json`.
- Uses `CLAUDE_CWD` pointing at a temp directory to avoid repeated folder confirmation.
- Retries once if parsing fails.

## JSON Parsing
- Required: `current_session_reset`.
- Optional: `current_session_percent`.
- Parses reset text into a Date with timezone handling.

## Environment Variables
- `TOKEN_MONITOR_DEBUG=1` : run as a regular app (not a menu bar only UI element).
- `TOKEN_MONITOR_FORCE_REGULAR=1` : force regular activation policy.
- `TOKEN_MONITOR_LOG_PATH=<path>` : override log file location.
- `TOKEN_MONITOR_CAPTURE_PATH=<path>` : override capture script path.
- `TOKEN_MONITOR_CAPTURE_RAW=<path>` : write raw `/status` output to file.
