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

## Change Checklist (to avoid regressions)
- Keep `mac-app/TokenMonitorMenuBar/TokenMonitorMenuBar/capture-status.py` in sync with `capture-status.py` before building the app.
- Prefer `/status` for current session reset time; `/stats` is aggregate and may not include the reset time you need.
- Tolerate TUI text corruption (e.g., missing letters in "Resets") when parsing reset lines.
- Handle the "Do you want to work in this folder?" prompt reliably or set `CLAUDE_CWD` to a safe temp dir.
- Ensure the capture script exits the Claude session even on timeouts to prevent runaway processes.
- If auto-bumping build numbers edits `Info.plist`, ensure user script sandboxing is disabled for that target.

## Verification Steps
- Run `/usr/bin/python3 capture-status.py --json --raw /tmp/claude-status.txt` and confirm `current_session_reset` is populated.
- Build the app and confirm `/Applications/TokenMonitorMenuBar.app/Contents/Resources/capture-status.py --json` returns the same fields.
- Check the menu bar shows `<percent>%|<HH:MM>` and that the countdown ticks each minute.
