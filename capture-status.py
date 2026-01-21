#!/usr/bin/env python3

import argparse
import os
import pty
import re
import select
import fcntl
import struct
import signal
import subprocess
import sys
import time
import json
from typing import Optional, Tuple


def strip_ansi(text: str) -> str:
    return re.sub(r"\x1B\[[0-9;]*[A-Za-z]", "", text)


def find_claude() -> str:
    """Find claude executable path dynamically."""
    # 1. 환경 변수 우선
    if os.environ.get("CLAUDE_PATH"):
        return os.environ["CLAUDE_PATH"]

    # 2. 일반적인 경로들 확인
    paths = [
        "/opt/homebrew/bin/claude",           # ARM Mac (Homebrew)
        "/usr/local/bin/claude",              # Intel Mac (Homebrew)
        os.path.expanduser("~/.claude/local/claude"),  # 로컬 설치
        os.path.expanduser("~/.local/bin/claude"),     # pip/pipx 설치
    ]
    for p in paths:
        if os.path.exists(p) and os.access(p, os.X_OK):
            return p

    # 3. which 명령어로 찾기
    try:
        result = subprocess.run(
            ["which", "claude"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass

    # 4. 폴백: PATH에서 찾기
    return "claude"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="output JSON summary")
    parser.add_argument("--raw", type=str, help="write raw output to file")
    args = parser.parse_args()
    master_fd, slave_fd = pty.openpty()
    # Set a default terminal size to ensure TUI renders.
    try:
        winsize = struct.pack("HHHH", 40, 120, 0, 0)
        fcntl.ioctl(slave_fd, 0x5414, winsize)  # TIOCSWINSZ
    except OSError:
        pass

    claude_path = find_claude()
    # cwd: 환경 변수 또는 임시 디렉토리 (앱 번들 Resources는 읽기 전용)
    cwd = os.environ.get("CLAUDE_CWD", os.path.expanduser("~"))
    proc = subprocess.Popen(
        [claude_path],
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        close_fds=True,
        cwd=cwd,
    )
    os.close(slave_fd)

    output = []
    start = time.time()
    sent_status = False
    sent_exit = False
    sent_tabs = 0
    last_tab_time = 0.0
    saw_settings = False
    saw_usage = False
    saw_prompt = False
    saw_status_hint = False
    saw_stats_hint = False
    sent_status_text = False
    status_text_at = 0.0
    status_sent_at = 0.0
    sent_stats = False
    saw_folder_confirm = False
    sent_folder_confirm = False
    sent_folder_confirm_at = 0.0
    folder_confirm_attempts = 0
    folder_confirm_first_seen = 0.0
    sent_usage_text = False
    usage_text_at = 0.0
    usage_sent_at = 0.0
    saw_usage_at = 0.0
    saw_reset_line = False

    try:
        def send_command(cmd: bytes) -> None:
            os.write(master_fd, b"/" + cmd)
            time.sleep(0.4)
            os.write(master_fd, b"\r")
            time.sleep(0.4)
            os.write(master_fd, b"\r")

        while True:
            now = time.time()

            # "Do you want to work in this folder?" 프롬프트 자동 승인
            if saw_folder_confirm and folder_confirm_first_seen == 0.0:
                folder_confirm_first_seen = now
            if saw_folder_confirm and (not sent_folder_confirm or (now - sent_folder_confirm_at > 2.0)) and folder_confirm_attempts < 3:
                time.sleep(0.3)
                os.write(master_fd, b"\r")  # Enter로 "Yes, continue" 선택
                sent_folder_confirm = True
                sent_folder_confirm_at = now
                folder_confirm_attempts += 1
                if folder_confirm_attempts == 1:
                    start = time.time()  # 타이머 리셋
            if saw_folder_confirm and folder_confirm_first_seen and now - folder_confirm_first_seen > 10:
                break

            if not sent_usage_text and saw_prompt and now - start > 3:
                send_command(b"status")
                sent_usage_text = True
                usage_text_at = now
                sent_status = True
                status_sent_at = now
                usage_sent_at = now

            if sent_status and not saw_usage and now - last_tab_time > 1.5:
                if saw_settings or (status_sent_at and now - status_sent_at > 8):
                    os.write(master_fd, b"\t")
                    sent_tabs += 1
                    last_tab_time = now
                    time.sleep(0.3)

            if sent_status and not saw_usage and (usage_sent_at and now - usage_sent_at > 8) and not sent_stats:
                send_command(b"stats")
                sent_stats = True
                usage_sent_at = now

            if sent_status and saw_usage and not sent_exit and (saw_reset_line or (saw_usage_at and now - saw_usage_at > 2.0)):
                os.write(master_fd, b"/exit\r")
                sent_exit = True

            if not sent_exit and now - start > 60:
                os.write(master_fd, b"/exit\r")
                sent_exit = True

            if now - start > 75:
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
                recent = strip_ansi(chunk.decode(errors="ignore"))
                if "❯" in recent:
                    saw_prompt = True
                if "Settings:" in recent:
                    saw_settings = True
                if "Do you want to work in this folder?" in recent or "Yes, continue" in recent:
                    saw_folder_confirm = True
                recent_lower = recent.lower()
                if sent_folder_confirm and ("welcome back" in recent_lower or "try \"" in recent_lower):
                    saw_folder_confirm = False
                if "try \"" in recent_lower or "for shortcuts" in recent_lower:
                    saw_prompt = True
                if "current session" in recent_lower:
                    saw_usage = True
                    if not saw_usage_at:
                        saw_usage_at = now
                if "reset" in recent_lower:
                    saw_reset_line = True
                if "/usage" in recent_lower:
                    saw_status_hint = True
                if "/status         Show Claude Code status" in recent:
                    saw_status_hint = True
                if "/stats                       Show your Claude Code usage statistics" in recent:
                    saw_stats_hint = True

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

    if args.raw:
        try:
            with open(args.raw, "w", encoding="utf-8") as f:
                f.write(clean)
        except OSError:
            pass
    lines = [line.strip() for line in clean.splitlines() if line.strip()]

    def normalize_reset_text(text: str) -> Optional[str]:
        match = re.search(r"rese[t]?s?\s*([^\n]+)", text, re.IGNORECASE)
        if match:
            return f"Resets {match.group(1).strip()}"
        return None

    def find_section(pattern_name: str):
        pattern = re.compile(pattern_name + r".*?(rese[t]?s?\s*[^\n]+)", re.DOTALL | re.IGNORECASE)
        match = pattern.search(clean)
        if match:
            return normalize_reset_text(match.group(1).strip())
        return None

    def find_percent(pattern_name: str):
        pattern = re.compile(pattern_name + r".*?(\d+)%\s*used", re.DOTALL | re.IGNORECASE)
        match = pattern.search(clean)
        if match:
            return int(match.group(1))
        return None

    def find_current_session_block(text: str) -> Optional[str]:
        pattern = re.compile(r"Current session(.*?)(Current week|$)", re.DOTALL | re.IGNORECASE)
        match = pattern.search(text)
        if match:
            return match.group(1)
        return None

    def parse_block_percent_and_reset(block: str) -> Tuple[Optional[int], Optional[str]]:
        percent_match = re.search(r"(\d+)%\s*used", block, re.IGNORECASE)
        reset_match = re.search(r"rese[t]?s?\s*([^\n]+)", block, re.IGNORECASE)
        percent = int(percent_match.group(1)) if percent_match else None
        reset = None
        if reset_match:
            reset = f"Resets {reset_match.group(1).strip()}"
        return percent, reset

    summary = []
    current_section = None
    percents = {}
    current_session_reset = None
    for line in lines:
        lowered = line.lower()
        if lowered.startswith("current session"):
            current_section = "current_session"
        elif lowered.startswith("current week (all models)"):
            current_section = "current_week_all"
        elif lowered.startswith("current week (sonnet only)"):
            current_section = "current_week_sonnet"
        elif current_section and "%" in line and "used" in line:
            match = re.search(r"(\d+)%\s*used", line)
            if match:
                percents[current_section] = int(match.group(1))
        elif current_section and re.match(r"rese", lowered):
            normalized = normalize_reset_text(line) or line
            summary.append(f"{current_section}: {normalized}")
            if current_section == "current_session":
                current_session_reset = normalized
            current_section = None

    if current_session_reset is None:
        block = find_current_session_block(clean)
        if block:
            percent, reset = parse_block_percent_and_reset(block)
            if percent is not None:
                percents["current_session"] = percent
            if reset:
                summary.append(f"current_session: {reset}")

    if not summary:
        reset = find_section("Current session")
        if reset:
            summary.append(f"current_session: {reset}")
        reset = find_section("Current week \\(all models\\)")
        if reset:
            summary.append(f"current_week_all: {reset}")
        reset = find_section("Current week \\(Sonnet only\\)")
        if reset:
            summary.append(f"current_week_sonnet: {reset}")
        percent = find_percent("Current session")
        if percent is not None:
            percents["current_session"] = percent

    if summary:
        seen = set()
        deduped = []
        for item in summary:
            if item in seen:
                continue
            seen.add(item)
            deduped.append(item)
        if args.json:
            payload = {
                "captured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "current_session_reset": None,
                "current_session_percent": percents.get("current_session"),
                "current_week_all_reset": None,
                "current_week_sonnet_reset": None,
                "source": "status_ui",
            }
            for item in deduped:
                if item.startswith("current_session:"):
                    payload["current_session_reset"] = item.split(":", 1)[1].strip()
                elif item.startswith("current_week_all:"):
                    payload["current_week_all_reset"] = item.split(":", 1)[1].strip()
                elif item.startswith("current_week_sonnet:"):
                    payload["current_week_sonnet_reset"] = item.split(":", 1)[1].strip()
            print(json.dumps(payload, ensure_ascii=True))
        else:
            print("\n".join(deduped))
    else:
        if args.json:
            payload = {
                "captured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "error": "parse_failed",
                "raw_tail": lines[-10:],
                "source": "status_ui",
            }
            print(json.dumps(payload, ensure_ascii=True))
        else:
            print("\n".join(lines[-20:]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
