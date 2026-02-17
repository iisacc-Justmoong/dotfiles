# Patch Notes

## 2026-02-18

### 시스템 정리
- `~/` 기준 생성 파일 정리 스크립트 `Scripts/machine-clean-generated.sh`를 추가했다.
- dotfiles 내부 Android 캐시/락 파일, `*.pysave`, `.DS_Store` 계열 정리 경로를 고정했다.
- 기존 `com.user.*.plist` 및 `*.command` 레거시 실행 파일 제거 상태를 유지했다.

### 머신 상태 백업/복원
- Dock/Finder 상태를 백업하는 `Scripts/machine-state-backup.sh`를 추가했다.
- 다음 날 Dock/Finder를 덮어쓰는 `Scripts/machine-state-apply-next-day.sh`를 추가했다.
- launchd 에이전트:
  - `macOS/com.dotfiles.machine-state-apply-next-day.plist` (02:50)
  - `macOS/com.dotfiles.machine-state-backup.plist` (03:00)
- `macOS/Scripts/launchctl.sh`를 신규 에이전트 기준으로 교체했다.

### 패키지/설정 보존 자동화
- 백업 스크립트에서 `brew bundle dump --force --file ~/.dotfiles/Brewfile`을 실행하도록 구성했다.
- `defaults read` 결과를 `machine-state/defaults/*.read.txt`로 저장하도록 구성했다.
- `defaults read` 결과를 기반으로 `defaults write` 복원 스크립트 `machine-state/defaults/apply-defaults-write.sh`를 자동 생성하도록 구성했다.

### 설치 흐름 정리
- `.command` 제거 정책에 맞춰 `macOS/Scripts/install_homebrew.sh`를 추가했다.
- `macOS/Setup.sh`에서 끊어진 경로(`Scripts/*`) 참조를 `macOS/...` 기반 경로로 정정했다.
