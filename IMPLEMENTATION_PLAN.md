# 메뉴바 토큰 모니터링 앱 구현 계획

## 목표
- 메뉴바에서 현재 토큰 사용량과 리셋 시점을 빠르게 확인.
- 수집은 `/status` 인터랙티브 캡처 기반.

## 단계별 작업
### 0) 실측 조사(필수)
- `/status` Usage 탭의 출력 항목 확인(리셋 시점, 세션/주간 사용량).
- 로컬 로그/캐시 존재 여부 확인.
- 결과를 `RESEARCH.md`에 업데이트.

### 1) 데이터 모델 정의
- 필수 필드: `timestamp`, `total_tokens`, `input_tokens`, `output_tokens`, `reset_at`, `source`.
- 선택 필드: `model`, `limit`, `currency`.
- 저장 포맷 결정: JSON(단순) vs SQLite(집계/통계).

### 2) 수집기(Collector) 구현
- `/status` PTY 자동 입력 모듈(실행 + Usage 탭 이동 + 파싱).
- 보조 소스: `~/.claude/stats-cache.json`, `~/.claude/projects/**/*.jsonl` 직접 파싱(선택).
- 리셋 카운트다운: `/status`의 “Resets … (Asia/Seoul)” 파싱 → `reset_at - now` 계산.
- 실패 처리: 타임아웃, 비정상 출력, 마지막 성공값 유지.
- 출력 표준화: 공통 모델로 매핑.

### 3) 메뉴바 앱 MVP
- SwiftUI + AppKit `NSStatusItem` 기반.
- 메뉴바 텍스트: `사용량/한도` 또는 `오늘 사용량`.
- 팝오버: 상세 정보(리셋 시점, 입력/출력 분리).
- 수동 새로고침 버튼.

### 4) 백그라운드 스케줄링
- 앱 내 타이머로 주기적 폴링(예: 60초).
- 필요 시 `launchd` 등록으로 재부팅 자동 실행.

### 5) 안정화/확장
- 실패 상태 표시(물음표/회색).
- 임계치 알림.
- 기간별 통계.
- 다중 프로파일 지원.

## 검증 체크리스트
- `/status` 파싱 성공률 95% 이상.
- 메뉴바 갱신 지연 2초 이내.
- 24시간 실행 시 메모리 누수 없음.

## 산출물
- `RESEARCH.md` 업데이트
- `IMPLEMENTATION_PLAN.md` (본 문서)
- Swift 메뉴바 앱 스켈레톤(후속)
