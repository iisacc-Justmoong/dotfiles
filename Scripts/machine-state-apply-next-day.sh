#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
STATE_DIR="${STATE_DIR:-$DOTFILES_DIR/machine-state}"
PLIST_DIR="$STATE_DIR/plists"
RUNTIME_DIR="$STATE_DIR/runtime"
METADATA_FILE="$STATE_DIR/metadata.env"
APPLY_MARKER="$RUNTIME_DIR/last_apply_date"
TODAY="$(date '+%Y-%m-%d')"

mkdir -p "$RUNTIME_DIR"

if [[ ! -f "$METADATA_FILE" ]]; then
  exit 0
fi

# shellcheck disable=SC1090
source "$METADATA_FILE"

if [[ -z "${BACKUP_DATE:-}" || "$BACKUP_DATE" == "$TODAY" ]]; then
  exit 0
fi

if [[ -f "$APPLY_MARKER" ]] && [[ "$(cat "$APPLY_MARKER")" == "$TODAY" ]]; then
  exit 0
fi

DOCK_SNAPSHOT="$PLIST_DIR/com.apple.dock.snapshot.plist"
FINDER_SNAPSHOT="$PLIST_DIR/com.apple.finder.snapshot.plist"

if [[ ! -f "$DOCK_SNAPSHOT" || ! -f "$FINDER_SNAPSHOT" ]]; then
  exit 0
fi

cp -f "$DOCK_SNAPSHOT" "$HOME/Library/Preferences/com.apple.dock.plist"
cp -f "$FINDER_SNAPSHOT" "$HOME/Library/Preferences/com.apple.finder.plist"
echo "$TODAY" >"$APPLY_MARKER"

killall Dock >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true
