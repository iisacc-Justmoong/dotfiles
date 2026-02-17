#!/bin/zsh
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
USER_UID="$(id -u)"

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
  cp -fv "$DOTFILES_DIR/macOS/$plist_name" "$LAUNCH_AGENTS_DIR/$plist_name"
  launchctl bootout "gui/$USER_UID" "$LAUNCH_AGENTS_DIR/$plist_name" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$USER_UID" "$LAUNCH_AGENTS_DIR/$plist_name"
  launchctl kickstart -k "gui/$USER_UID/${plist_name%.plist}" >/dev/null 2>&1 || true
done

ls -l "$LAUNCH_AGENTS_DIR" | grep "com.dotfiles.machine" || true
