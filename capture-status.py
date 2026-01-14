#!/usr/bin/env python3

import os
import pty
import re
import select
import signal
import subprocess
import sys
import time


def strip_ansi(text: str) -> str:
    return re.sub(r"\x1B\[[0-9;]*[A-Za-z]", "", text)


def main() -> int:
    master_fd, slave_fd = pty.openpty()
    proc = subprocess.Popen(
        ["claude"],
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        close_fds=True,
    )
    os.close(slave_fd)

    output = []
    start = time.time()
    sent_status = False
    sent_exit = False
    sent_tabs = 0

    try:
        while True:
            now = time.time()

            if not sent_status and now - start > 3:
                os.write(master_fd, b"\x1b")  # ESC to clear suggestion
                time.sleep(0.1)
                os.write(master_fd, b"\x15")  # Ctrl+U to clear input
                time.sleep(0.1)
                os.write(master_fd, b"/status\r")
                time.sleep(0.4)
                os.write(master_fd, b"\r")
                sent_status = True

            if sent_status and sent_tabs < 2 and now - start > 5 + sent_tabs * 0.5:
                os.write(master_fd, b"\t")
                sent_tabs += 1

            if sent_status and not sent_exit and now - start > 10:
                os.write(master_fd, b"/exit\r")
                sent_exit = True

            if sent_exit and now - start > 20:
                break

            rlist, _, _ = select.select([master_fd], [], [], 0.2)
            if master_fd in rlist:
                try:
                    chunk = os.read(master_fd, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output.append(chunk)

            if proc.poll() is not None:
                break
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        if proc.poll() is None:
            proc.send_signal(signal.SIGTERM)

    raw = b"".join(output).decode(errors="ignore")
    clean = strip_ansi(raw)
    lines = [line.strip() for line in clean.splitlines() if line.strip()]

    summary = []
    current_section = None
    for line in lines:
        if line.startswith("Current session"):
            current_section = "current_session"
        elif line.startswith("Current week (all models)"):
            current_section = "current_week_all"
        elif line.startswith("Current week (Sonnet only)"):
            current_section = "current_week_sonnet"
        elif line.startswith("Resets") and current_section:
            summary.append(f"{current_section}: {line}")
            current_section = None

    if summary:
        seen = set()
        deduped = []
        for item in summary:
            if item in seen:
                continue
            seen.add(item)
            deduped.append(item)
        print("\n".join(deduped))
    else:
        print("\n".join(lines[-20:]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
