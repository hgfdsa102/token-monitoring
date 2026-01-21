# check-claude-usage.exp Spec

## Overview
An Expect script that automates `/status` in the `claude` CLI and ensures the spawned process exits even on timeouts or signals.

## Behavior
- `spawn claude`
- Waits for initial render, clears the input line, sends `/status`.
- After a short delay, sends `/exit`.
- Waits for EOF with a short timeout.
- On timeout or SIGINT/SIGTERM:
  - Sends `/exit`
  - Closes the PTY and waits for process termination
  - Sends `SIGTERM` then `SIGKILL` to the `claude` PID if needed

## Timing
- Global timeout: 90 seconds
- `/status` send delay: ~3 seconds after spawn
- `/exit` send delay: ~5 seconds after status
- `/exit` wait timeout: 15 seconds

## Output
- Uses `log_user 1`, so all output from the `claude` session is printed to stdout.
- On cleanup, prints: `Cleanup: <reason>`
