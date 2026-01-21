#!/bin/bash

# Claude Code 사용량 확인 래퍼 스크립트
# 사용법: ./check-claude-usage.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# python3 확인
if ! command -v /usr/bin/python3 &> /dev/null; then
    echo "Error: python3가 설치되어 있지 않습니다."
    exit 1
fi

# claude 설치 확인
if ! command -v claude &> /dev/null; then
    echo "Error: claude가 설치되어 있지 않습니다."
    exit 1
fi

# 인터랙티브 /status 캡처 (PTY)
echo "=== Claude Code 사용량 조회 ==="
echo ""

if [[ "$1" == "--json" ]]; then
    RAW_OUTPUT="$(/usr/bin/python3 "$SCRIPT_DIR/capture-status.py" --json)"
else
    RAW_OUTPUT="$(/usr/bin/python3 "$SCRIPT_DIR/capture-status.py")"
fi
printf "%s\n" "$RAW_OUTPUT" | grep -v "^$"

echo ""
echo "=== 조회 완료 ==="
