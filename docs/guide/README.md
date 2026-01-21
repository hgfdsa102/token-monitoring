# Token Monitoring Guide

## Purpose
This project captures Claude Code usage from the interactive `/status` UI and surfaces it in scripts and a macOS menu bar app.

## Prerequisites
- macOS (for the menu bar app)
- `claude` CLI installed and logged in
- `/usr/bin/python3` available
- `expect` (only if using `check-claude-usage.exp`)

## Quick Usage

### CLI status capture
- Human-readable:
  - `./check-claude-usage.sh`
- JSON summary:
  - `./check-claude-usage.sh --json`

### Direct capture script
- Human-readable:
  - `./capture-status.py`
- JSON summary:
  - `./capture-status.py --json`
- Write raw output:
  - `./capture-status.py --raw /tmp/claude-status.txt`

### Expect-based check
- `./check-claude-usage.exp`

## Menu Bar App (macOS)
- Project: `mac-app/TokenMonitorMenuBar/TokenMonitorMenuBar.xcodeproj`
- Open in Xcode and run the `TokenMonitorMenuBar` target.
- The menu bar item shows usage percent and a countdown.

## Environment Variables
- `TOKEN_MONITOR_DEBUG=1` : run the app as a regular app (not a menu bar only UI element).
- `TOKEN_MONITOR_FORCE_REGULAR=1` : force regular activation policy.
- `TOKEN_MONITOR_LOG_PATH=<path>` : override log file location.
- `TOKEN_MONITOR_CAPTURE_PATH=<path>` : override capture script path.
- `TOKEN_MONITOR_CAPTURE_RAW=<path>` : write raw `/status` output to file.
- `CLAUDE_PATH=<path>` : override the `claude` CLI path used by `capture-status.py`.
- `CLAUDE_CWD=<path>` : override the working directory for `claude`.

## Notes
- The capture scripts use a PTY to drive `/status` and parse the output.
- If `/status` changes its UI, parsing may need updates.
