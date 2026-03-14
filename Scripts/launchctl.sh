#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PLIST_SOURCE_DIR="$DOTFILES_DIR/macOS"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
USER_UID="$(id -u)"

rewrite_managed_plist_program() {
  local plist_path="$1"
  local label script_path

  label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist_path" 2>/dev/null || true)"
  script_path=""

  case "$label" in
    "com.dotfiles.machine-env-guard")
      script_path="$DOTFILES_DIR/Scripts/machine-env-guard.sh"
      ;;
    "com.dotfiles.machine-state-apply-next-day")
      script_path="$DOTFILES_DIR/Scripts/machine-state-apply-next-day.sh"
      ;;
    "com.dotfiles.machine-state-backup")
      script_path="$DOTFILES_DIR/Scripts/machine-state-backup.sh"
      ;;
  esac

  [[ -n "$script_path" && -f "$script_path" ]] || return 0

  /usr/libexec/PlistBuddy -c "Delete :ProgramArguments" "$plist_path" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :ProgramArguments array" "$plist_path" >/dev/null
  /usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string $script_path" "$plist_path" >/dev/null
}

mkdir -p "$LAUNCH_AGENTS_DIR"

typeset -a legacy_labels
legacy_labels=(
  "com.user.SafariAutomaticStableDiffusionWindow"
  "com.user.LaunchTasks"
  "com.user.LaunchMusicPlay"
)

for label in "${legacy_labels[@]}"; do
  launchctl bootout "gui/$USER_UID" "$LAUNCH_AGENTS_DIR/$label.plist" >/dev/null 2>&1 || true
done

typeset -a managed_plists
managed_plists=(
  "com.dotfiles.machine-env-guard.plist"
  "com.dotfiles.machine-state-apply-next-day.plist"
  "com.dotfiles.machine-state-backup.plist"
)

for plist_name in "${managed_plists[@]}"; do
  cp -fv "$PLIST_SOURCE_DIR/$plist_name" "$LAUNCH_AGENTS_DIR/$plist_name"
  rewrite_managed_plist_program "$LAUNCH_AGENTS_DIR/$plist_name"
  launchctl bootout "gui/$USER_UID" "$LAUNCH_AGENTS_DIR/$plist_name" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$USER_UID" "$LAUNCH_AGENTS_DIR/$plist_name"
  launchctl kickstart -k "gui/$USER_UID/${plist_name%.plist}" >/dev/null 2>&1 || true
done

ls -l "$LAUNCH_AGENTS_DIR" | grep "com.dotfiles.machine" || true
