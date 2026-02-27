#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MACOS_DIR="$DOTFILES_DIR/macOS"
SCRIPTS_DIR="$DOTFILES_DIR/Scripts"
STATE_DIR="$DOTFILES_DIR/machine-state"
PLIST_STATE_DIR="$STATE_DIR/plists"
DEFAULTS_APPLY_SCRIPT="$STATE_DIR/defaults/apply-defaults-write.sh"

log() {
  printf '[setup] %s\n' "$1"
}

fail() {
  printf '[setup][error] %s\n' "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "required file missing: $path"
}

ensure_dotfiles_home_link() {
  local canonical_dotfiles="$HOME/.dotfiles"

  if [[ "$DOTFILES_DIR" == "$canonical_dotfiles" ]]; then
    return 0
  fi

  if [[ -e "$canonical_dotfiles" && ! -L "$canonical_dotfiles" ]]; then
    fail "$canonical_dotfiles exists as a regular file/dir. replace it with symlink to $DOTFILES_DIR"
  fi

  ln -sfn "$DOTFILES_DIR" "$canonical_dotfiles"
  log "canonical link enforced: $canonical_dotfiles -> $DOTFILES_DIR"
}

grant_exec_permissions() {
  chmod +x "$SCRIPTS_DIR"/*.sh
  chmod +x "$MACOS_DIR"/Scripts/*.sh
  chmod +x "$MACOS_DIR"/macos
  chmod +x "$MACOS_DIR"/shell/symlink.sh
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode CLT already installed"
    return 0
  fi

  log "installing Xcode CLT (GUI prompt may appear)"
  xcode-select --install >/dev/null 2>&1 || true

  log "waiting for Xcode CLT installation"
  local retries=0
  until xcode-select -p >/dev/null 2>&1; do
    retries=$((retries + 1))
    if [[ "$retries" -ge 120 ]]; then
      fail "Xcode CLT installation timeout. install it manually, then rerun Setup.sh"
    fi
    sleep 5
  done

  log "Xcode CLT installation confirmed"
}

apply_machine_state_defaults() {
  if [[ -f "$DEFAULTS_APPLY_SCRIPT" ]]; then
    log "applying captured defaults from machine-state"
    bash "$DEFAULTS_APPLY_SCRIPT"
  else
    log "captured defaults script not found, skipping"
  fi
}

restore_dock_finder_snapshot() {
  local dock_snapshot="$PLIST_STATE_DIR/com.apple.dock.snapshot.plist"
  local finder_snapshot="$PLIST_STATE_DIR/com.apple.finder.snapshot.plist"
  local dock_export="$PLIST_STATE_DIR/com.apple.dock.export.plist"
  local finder_export="$PLIST_STATE_DIR/com.apple.finder.export.plist"

  if [[ -f "$dock_snapshot" ]]; then
    cp -f "$dock_snapshot" "$HOME/Library/Preferences/com.apple.dock.plist"
  elif [[ -f "$dock_export" ]]; then
    cp -f "$dock_export" "$HOME/Library/Preferences/com.apple.dock.plist"
  fi

  if [[ -f "$finder_snapshot" ]]; then
    cp -f "$finder_snapshot" "$HOME/Library/Preferences/com.apple.finder.plist"
  elif [[ -f "$finder_export" ]]; then
    cp -f "$finder_export" "$HOME/Library/Preferences/com.apple.finder.plist"
  fi

  killall Dock >/dev/null 2>&1 || true
  killall Finder >/dev/null 2>&1 || true
}

main() {
  log "dotfiles setup start for user: $(whoami)"
  zsh --version

  require_file "$DOTFILES_DIR/Brewfile"
  require_file "$MACOS_DIR/Scripts/install_homebrew.sh"
  require_file "$MACOS_DIR/macos"
  require_file "$MACOS_DIR/shell/symlink.sh"

  ensure_dotfiles_home_link
  grant_exec_permissions
  ensure_xcode_clt

  "$MACOS_DIR/Scripts/install_homebrew.sh"
  log "Homebrew installed"

  "$MACOS_DIR/shell/symlink.sh"
  log "symlink setup applied"

  "$MACOS_DIR/macos"
  log "static macOS defaults applied"

  apply_machine_state_defaults
  restore_dock_finder_snapshot
  log "captured machine-state restored"

  log "installing packages from Brewfile"
  brew bundle --file "$DOTFILES_DIR/Brewfile"
  log "package install completed"

  brew doctor
  brew --version
  ls -l "$DOTFILES_DIR"
  log "dotfiles setup completed"
}

main "$@"
