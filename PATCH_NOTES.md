# Patch Notes

## 2026-02-18

### Environment Guard Automation (launchd/launchctl)
- Added `Scripts/machine-env-guard.sh` as a 30-minute environment guard.
- Guard behavior:
- Verifies home-directory symlink integrity and repairs drift automatically.
- Runs the generated-file cleanup script.
- Triggers `machine-state-backup.sh` when the daily backup is missing.
- Runs `dev-env-doctor.sh` periodically and keeps its logs.
- Detects unexpected root ownership inside `.git` and repairs it when possible.
- Added `macOS/com.dotfiles.machine-env-guard.plist` and integrated it into `Scripts/launchctl.sh` for automatic bootstrap and kickstart registration.

### System Cleanup
- Added `Scripts/machine-clean-generated.sh` for regenerable files under `~/`.
- Fixed cleanup targets for Android cache and lock files, `*.pysave`, and `.DS_Store` artifacts inside dotfiles.
- Preserved removal of legacy `com.user.*.plist` entries and `*.command` launchers.

### Machine State Backup and Restore
- Added `Scripts/machine-state-backup.sh` to capture Dock and Finder state.
- Added `Scripts/machine-state-apply-next-day.sh` to re-apply Dock and Finder state on the next day.
- launchd agents:
- `macOS/com.dotfiles.machine-state-apply-next-day.plist` (02:50)
- `macOS/com.dotfiles.machine-state-backup.plist` (03:00)
- Replaced `Scripts/launchctl.sh` with the managed agent set.
- Added `launchctl print` snapshots for headless user services that match `openclaw`, `gateway`, `watchdog`, or `headless`.
- Normalized restored user LaunchAgents so home-dependent paths are rewritten for the current user during restore.

### Package and Preference Preservation
- Configured the backup script to run `brew bundle dump --force --file "$DOTFILES_DIR/Brewfile"`.
- Stored `defaults read` output under `macOS/machine-state/defaults/*.read.txt`.
- Generated `macOS/machine-state/defaults/apply-defaults-write.sh` from captured `defaults read` output.

### Setup Flow
- Added `Scripts/install_homebrew.sh` under the `.command` removal policy.
- Reworked `macOS/Setup.sh` and the machine-state scripts around `macOS/machine-state` and the root `Scripts/` directory.
