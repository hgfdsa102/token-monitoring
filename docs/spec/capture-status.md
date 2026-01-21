# capture-status.py Spec

## Overview
`capture-status.py` launches the `claude` CLI in a PTY, sends `/status`, navigates to the Usage view, and parses usage/reset data from the rendered UI.

## Inputs
- Args:
  - `--json`: output JSON summary
  - `--raw <path>`: write raw `/status` output to a file
- Env:
  - `CLAUDE_PATH`: override the `claude` executable path
  - `CLAUDE_CWD`: working directory for `claude` (defaults to `~`)

## Behavior
- Spawns `claude` attached to a PTY with a fixed terminal size.
- Detects the prompt and types `/status` character-by-character for reliable TUI handling.
- Tabs until the Usage view is visible (`Current session`).
- Auto-accepts the "Do you want to work in this folder?" confirmation by sending Enter.
- Sends `/exit` after Usage is detected or after a timeout.
- Hard timeout exits after ~45 seconds.

## Output
### JSON (`--json`)
```
{
  "captured_at": "2025-01-21T05:12:34Z",
  "current_session_reset": "Resets 7pm (Asia/Seoul)",
  "current_session_percent": 42,
  "current_week_all_reset": "Resets Fri 7pm (Asia/Seoul)",
  "current_week_sonnet_reset": "Resets Fri 7pm (Asia/Seoul)",
  "source": "status_ui"
}
```
- On parse failure:
```
{
  "captured_at": "...",
  "error": "parse_failed",
  "raw_tail": ["..."],
  "source": "status_ui"
}
```

### Text (default)
- One line per section in the form:
  - `current_session: Resets 7pm (Asia/Seoul)`

## Parsing Notes
- Usage percent is extracted from lines containing `"% used"`.
- Reset text is extracted from lines starting with `Resets` within each section.
- ANSI sequences are stripped before parsing.
