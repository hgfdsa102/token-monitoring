# TokenMonitorMenuBar 배포 계획

## 목표
- 앱 번들만 복사하면 다른 사람도 사용 가능하도록 자체 완결형 앱 구성
- 외부 의존성 최소화

## 구현 상태

| 항목 | 상태 | 설명 |
|------|------|------|
| capture-status.py 번들 포함 | ✅ 완료 | `Contents/Resources/capture-status.py` |
| claude 경로 동적 탐지 | ✅ 완료 | ARM/Intel Mac 자동 감지 |
| 폴더 확인 프롬프트 자동 처리 | ✅ 완료 | "Do you want to work in this folder?" 자동 승인 |
| Ad-hoc 코드 서명 | ✅ 완료 | Gatekeeper 경고 방지 |

## 앱 번들 구조

```
TokenMonitorMenuBar.app/
└── Contents/
    ├── MacOS/
    │   └── TokenMonitorMenuBar     # 실행 파일
    ├── Resources/
    │   └── capture-status.py       # 데이터 캡처 스크립트
    ├── Info.plist
    └── _CodeSignature/             # 코드 서명
```

## 빌드 및 배포

### 빌드
```bash
cd ~/github/token-monitoring/mac-app/TokenMonitorMenuBar
xcodebuild -scheme TokenMonitorMenuBar -configuration Release build
```

### 코드 서명 (필수)
서명 없이 배포하면 다른 Mac에서 "응용프로그램을 열 수 없습니다" 오류 발생.

```bash
# Ad-hoc 서명 (개발자 ID 없이)
codesign --force --deep --sign - /path/to/TokenMonitorMenuBar.app

# 서명 확인
codesign -dv --verbose=4 /path/to/TokenMonitorMenuBar.app
```

### Applications에 설치
```bash
cp -R ~/Library/Developer/Xcode/DerivedData/TokenMonitorMenuBar-*/Build/Products/Release/TokenMonitorMenuBar.app /Applications/
codesign --force --deep --sign - /Applications/TokenMonitorMenuBar.app
```

## 배포 방법

### 방법 1: .app 직접 배포
```bash
# 서명 후 zip으로 압축
cd /Applications
zip -r TokenMonitorMenuBar.zip TokenMonitorMenuBar.app
```

### 방법 2: 수신자 측 설치
```bash
# 1. zip 압축 해제 후 Applications로 이동
# 2. 터미널에서 quarantine 속성 제거
xattr -cr /Applications/TokenMonitorMenuBar.app

# 3. 실행
open /Applications/TokenMonitorMenuBar.app
```

### Gatekeeper 우회 (서명 없는 앱)
서명이 없는 앱을 받은 경우:

1. **우클릭 → 열기** (권장)
2. 또는 터미널에서:
   ```bash
   xattr -cr /Applications/TokenMonitorMenuBar.app
   ```
3. 또는 **시스템 설정 → 개인정보 보호 및 보안 → "확인 없이 열기"**

## 사용자 요구사항

| 항목 | 필수 여부 | 비고 |
|------|----------|------|
| macOS 13+ | 필수 | 앱 최소 요구사항 |
| Claude Code CLI | 필수 | `npm install -g @anthropic-ai/claude-code` |
| Claude Max 구독 | 필수 | /status 사용을 위해 |
| python3 | 기본 포함 | macOS 기본 제공 |

## 환경 변수 (선택)

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `CLAUDE_PATH` | claude 실행 파일 경로 | 자동 탐지 |
| `CLAUDE_CWD` | claude 실행 디렉토리 | 임시 디렉토리 |
| `TOKEN_MONITOR_CAPTURE_PATH` | capture-status.py 경로 | 앱 번들 내 Resources |
| `TOKEN_MONITOR_CAPTURE_RAW` | raw 출력 저장 경로 | 없음 |
| `TOKEN_MONITOR_LOG_PATH` | 로그 파일 경로 | `~/Library/Logs/TokenMonitorMenuBar.log` |

## claude 경로 탐지 순서

1. 환경 변수 `CLAUDE_PATH`
2. `/opt/homebrew/bin/claude` (ARM Mac)
3. `/usr/local/bin/claude` (Intel Mac)
4. `~/.claude/local/claude`
5. `~/.local/bin/claude`
6. `which claude` 결과
7. `claude` (PATH에서 찾기)

## 문제 해결

### "응용프로그램을 열 수 없습니다"
```bash
xattr -cr /Applications/TokenMonitorMenuBar.app
```

### 메뉴바에 "--:--" 표시
- Claude Code CLI가 설치되어 있는지 확인
- `claude` 명령어가 터미널에서 동작하는지 확인
- 로그 확인: `cat ~/Library/Logs/TokenMonitorMenuBar.log`

### claude 경로를 찾지 못함
```bash
# 환경 변수로 직접 지정
export CLAUDE_PATH=/path/to/claude
open /Applications/TokenMonitorMenuBar.app
```
