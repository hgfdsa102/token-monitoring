# check-claude-usage.sh Spec

## Overview
Shell wrapper around `capture-status.py` for quick interactive usage.

## Behavior
- Verifies `/usr/bin/python3` is available.
- Verifies `claude` is on PATH.
- Runs `capture-status.py` and prints results.
- Supports `--json` to forward JSON output.

## Usage
- `./check-claude-usage.sh`
- `./check-claude-usage.sh --json`
