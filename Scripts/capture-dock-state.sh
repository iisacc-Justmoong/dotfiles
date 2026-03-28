#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MACOS_DIR="$DOTFILES_DIR/macOS"
STATE_DIR="${STATE_DIR:-$MACOS_DIR/machine-state}"
PLIST_DIR="$STATE_DIR/plists"

mkdir -p "$MACOS_DIR" "$PLIST_DIR"

TMP_EXPORT="$(mktemp "${TMPDIR:-/tmp}/dock-export.XXXXXX.plist")"
cleanup() {
  rm -f "$TMP_EXPORT"
}
trap cleanup EXIT

if defaults export com.apple.dock "$TMP_EXPORT" >/dev/null 2>&1; then
  cp -f "$TMP_EXPORT" "$MACOS_DIR/com.apple.dock.plist"
  cp -f "$TMP_EXPORT" "$PLIST_DIR/com.apple.dock.snapshot.plist"
  cp -f "$TMP_EXPORT" "$PLIST_DIR/com.apple.dock.export.plist"
  echo "[dock] captured latest Dock session state"
  exit 0
fi

SOURCE_PLIST="$HOME/Library/Preferences/com.apple.dock.plist"
if [[ -f "$SOURCE_PLIST" ]]; then
  cp -f "$SOURCE_PLIST" "$MACOS_DIR/com.apple.dock.plist"
  cp -f "$SOURCE_PLIST" "$PLIST_DIR/com.apple.dock.snapshot.plist"
  cp -f "$SOURCE_PLIST" "$PLIST_DIR/com.apple.dock.export.plist"
  echo "[dock] captured Dock plist via file copy fallback"
  exit 0
fi

echo "[dock][error] unable to capture current Dock state" >&2
exit 1
