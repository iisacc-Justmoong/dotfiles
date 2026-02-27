#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MACOS_DIR="$DOTFILES_DIR/macOS"
SCRIPTS_DIR="$DOTFILES_DIR/Scripts"
STATE_DIR="$DOTFILES_DIR/machine-state"
PLIST_STATE_DIR="$STATE_DIR/plists"
DEFAULTS_STATE_DIR="$STATE_DIR/defaults"
PREFERENCES_STATE_DIR="$STATE_DIR/preferences"
LAUNCHD_STATE_DIR="$STATE_DIR/launchd"
PACKAGES_STATE_DIR="$STATE_DIR/packages"
SYSTEM_STATE_DIR="$STATE_DIR/system"
METADATA_FILE="$STATE_DIR/metadata.env"
SUMMARY_FILE="$STATE_DIR/backup-summary.txt"
DEFAULTS_APPLY_SCRIPT="$STATE_DIR/defaults/apply-defaults-write.sh"
SUDO_READY=0

log() {
  printf '[setup] %s\n' "$1"
}

warn() {
  printf '[setup][warn] %s\n' "$1"
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

has_entries() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
}

ensure_sudo_session() {
  if [[ "$SUDO_READY" -eq 1 ]]; then
    return 0
  fi

  if sudo -n true >/dev/null 2>&1; then
    SUDO_READY=1
    return 0
  fi

  log "sudo authentication required for privileged restore"
  sudo -v || fail "sudo authentication failed"
  SUDO_READY=1
}

copy_dir_contents() {
  local src="$1"
  local dst="$2"

  [[ -d "$src" ]] || return 0
  mkdir -p "$dst"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$src"/ "$dst"/
    return 0
  fi

  local path
  while IFS= read -r path; do
    cp -R "$path" "$dst"/
  done < <(find "$src" -mindepth 1 -maxdepth 1 -print)
}

copy_dir_contents_sudo() {
  local src="$1"
  local dst="$2"

  [[ -d "$src" ]] || return 0
  ensure_sudo_session
  sudo mkdir -p "$dst"

  if command -v rsync >/dev/null 2>&1; then
    sudo rsync -a "$src"/ "$dst"/
    return 0
  fi

  local path
  while IFS= read -r path; do
    sudo cp -R "$path" "$dst"/
  done < <(find "$src" -mindepth 1 -maxdepth 1 -print)
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

verify_machine_state_coverage() {
  local required_paths
  required_paths=(
    "$DEFAULTS_STATE_DIR"
    "$PLIST_STATE_DIR"
    "$PREFERENCES_STATE_DIR"
    "$LAUNCHD_STATE_DIR"
    "$PACKAGES_STATE_DIR"
    "$SYSTEM_STATE_DIR"
  )

  local path
  for path in "${required_paths[@]}"; do
    if [[ -d "$path" ]]; then
      log "machine-state source found: $path"
    else
      warn "machine-state source missing: $path"
    fi
  done

  [[ -f "$SUMMARY_FILE" ]] && log "machine-state summary found: $SUMMARY_FILE"
}

apply_machine_state_defaults() {
  if [[ -f "$DEFAULTS_APPLY_SCRIPT" ]]; then
    log "applying captured defaults from machine-state"
    bash "$DEFAULTS_APPLY_SCRIPT"
  else
    warn "captured defaults script not found, skipping"
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

restore_preferences_snapshot() {
  local user_src="$PREFERENCES_STATE_DIR/user"
  local byhost_src="$PREFERENCES_STATE_DIR/byhost"
  local user_dst="$HOME/Library/Preferences"
  local byhost_dst="$HOME/Library/Preferences/ByHost"

  if ! has_entries "$user_src" && ! has_entries "$byhost_src"; then
    warn "preferences snapshot not found, skipping"
    return 0
  fi

  has_entries "$user_src" && copy_dir_contents "$user_src" "$user_dst"
  has_entries "$byhost_src" && copy_dir_contents "$byhost_src" "$byhost_dst"

  killall cfprefsd >/dev/null 2>&1 || true
  log "preferences snapshot restored"
}

rewrite_dotfiles_launchagent_program() {
  local plist="$1"
  local label script_path

  label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null || true)"
  script_path=""

  case "$label" in
    "com.dotfiles.machine-env-guard")
      script_path="$SCRIPTS_DIR/machine-env-guard.sh"
      ;;
    "com.dotfiles.machine-state-apply-next-day")
      script_path="$SCRIPTS_DIR/machine-state-apply-next-day.sh"
      ;;
    "com.dotfiles.machine-state-backup")
      script_path="$SCRIPTS_DIR/machine-state-backup.sh"
      ;;
  esac

  if [[ -n "$script_path" && -f "$script_path" ]]; then
    /usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 $script_path" "$plist" >/dev/null 2>&1 || true
  fi
}

restore_user_launchagents() {
  local src="$LAUNCHD_STATE_DIR/user-LaunchAgents"
  local dst="$HOME/Library/LaunchAgents"
  local uid plist_name plist_path label

  has_entries "$src" || {
    warn "user launchagents snapshot not found, skipping"
    return 0
  }

  uid="$(id -u)"
  mkdir -p "$dst"
  copy_dir_contents "$src" "$dst"

  while IFS= read -r plist_name; do
    plist_path="$dst/$plist_name"
    [[ -f "$plist_path" ]] || continue
    rewrite_dotfiles_launchagent_program "$plist_path"
    launchctl bootout "gui/$uid" "$plist_path" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$uid" "$plist_path" >/dev/null 2>&1 || true
    label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist_path" 2>/dev/null || true)"
    [[ -n "$label" ]] && launchctl kickstart -k "gui/$uid/$label" >/dev/null 2>&1 || true
  done < <(find "$src" -maxdepth 1 -type f -name '*.plist' -exec basename {} \; | sort)

  log "user launchagents restored"
}

restore_system_launchd() {
  local src_agents="$LAUNCHD_STATE_DIR/system-LaunchAgents"
  local src_daemons="$LAUNCHD_STATE_DIR/system-LaunchDaemons"
  local plist_name dst_path

  if ! has_entries "$src_agents" && ! has_entries "$src_daemons"; then
    warn "system launchd snapshot not found, skipping"
    return 0
  fi

  has_entries "$src_agents" && copy_dir_contents_sudo "$src_agents" "/Library/LaunchAgents"
  has_entries "$src_daemons" && copy_dir_contents_sudo "$src_daemons" "/Library/LaunchDaemons"

  if has_entries "$src_agents"; then
    while IFS= read -r plist_name; do
      dst_path="/Library/LaunchAgents/$plist_name"
      [[ -f "$dst_path" ]] || continue
      sudo launchctl bootout system "$dst_path" >/dev/null 2>&1 || true
      sudo launchctl bootstrap system "$dst_path" >/dev/null 2>&1 || true
    done < <(find "$src_agents" -maxdepth 1 -type f -name '*.plist' -exec basename {} \; | sort)
  fi

  if has_entries "$src_daemons"; then
    while IFS= read -r plist_name; do
      dst_path="/Library/LaunchDaemons/$plist_name"
      [[ -f "$dst_path" ]] || continue
      sudo launchctl bootout system "$dst_path" >/dev/null 2>&1 || true
      sudo launchctl bootstrap system "$dst_path" >/dev/null 2>&1 || true
    done < <(find "$src_daemons" -maxdepth 1 -type f -name '*.plist' -exec basename {} \; | sort)
  fi

  log "system launchd restored"
}

restore_host_identity() {
  [[ -f "$METADATA_FILE" ]] || {
    warn "metadata file not found, skipping host identity restore"
    return 0
  }

  # shellcheck disable=SC1090
  source "$METADATA_FILE"

  if [[ -n "${OS_VERSION:-}" && "$OS_VERSION" != "unknown" ]]; then
    local current_os
    current_os="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
    if [[ "$current_os" != "$OS_VERSION" ]]; then
      warn "OS version differs from backup (current=$current_os backup=$OS_VERSION)"
    fi
  fi

  if [[ -n "${COMPUTER_NAME:-}" && "$COMPUTER_NAME" != "unknown" ]]; then
    ensure_sudo_session
    sudo scutil --set ComputerName "$COMPUTER_NAME" || warn "failed to restore ComputerName"
  fi

  if [[ -n "${LOCAL_HOST_NAME:-}" && "$LOCAL_HOST_NAME" != "unknown" ]]; then
    ensure_sudo_session
    sudo scutil --set LocalHostName "$LOCAL_HOST_NAME" || warn "failed to restore LocalHostName"
  fi

  if [[ -n "${HOST_NAME:-}" && "$HOST_NAME" != "unknown" ]]; then
    ensure_sudo_session
    sudo scutil --set HostName "$HOST_NAME" || warn "failed to restore HostName"
  fi

  log "host identity restore completed"
}

restore_crontab_snapshot() {
  local state_file="$SYSTEM_STATE_DIR/crontab.txt"
  [[ -f "$state_file" ]] || return 0

  if grep -qE '^\[missing command\]|^\[exit code\]' "$state_file"; then
    warn "crontab snapshot is not restorable, skipping"
    return 0
  fi

  if grep -q '^no crontab for ' "$state_file"; then
    log "backup source had no crontab"
    return 0
  fi

  crontab "$state_file" >/dev/null 2>&1 || warn "crontab restore failed"
  log "crontab restore attempted"
}

restore_pmset_snapshot() {
  local state_file="$SYSTEM_STATE_DIR/pmset.g.txt"
  [[ -f "$state_file" ]] || return 0

  local key value
  local restored_any=0

  while read -r key value; do
    [[ -n "$key" && -n "$value" ]] || continue
    ensure_sudo_session
    sudo pmset -a "$key" "$value" >/dev/null 2>&1 || warn "pmset restore failed for $key=$value"
    restored_any=1
  done < <(awk '/^[[:space:]]+[A-Za-z0-9_-]+[[:space:]]+[-]?[0-9]+$/ {print $1, $2}' "$state_file")

  [[ "$restored_any" -eq 1 ]] && log "pmset restore attempted"
}

restore_system_state() {
  restore_host_identity
  restore_crontab_snapshot
  restore_pmset_snapshot
}

restore_mas_packages() {
  local state_file="$PACKAGES_STATE_DIR/mas.list.txt"
  [[ -f "$state_file" ]] || return 0
  command -v mas >/dev/null 2>&1 || return 0

  local app_id
  while IFS= read -r app_id; do
    [[ -n "$app_id" ]] || continue
    mas install "$app_id" >/dev/null 2>&1 || warn "mas install failed for id=$app_id"
  done < <(awk '/^[0-9]+ / {print $1}' "$state_file")

  log "mas packages restore attempted"
}

restore_npm_globals() {
  local state_file="$PACKAGES_STATE_DIR/npm.global.txt"
  [[ -f "$state_file" ]] || return 0
  command -v npm >/dev/null 2>&1 || return 0

  local pkg
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    npm install -g "$pkg" >/dev/null 2>&1 || warn "npm global install failed for $pkg"
  done < <(grep -oE '(@[A-Za-z0-9._-]+/[A-Za-z0-9._-]+|[A-Za-z0-9._-]+)@[0-9][A-Za-z0-9._+-]*' "$state_file" | sort -u || true)

  log "npm global restore attempted"
}

restore_pip3_packages() {
  local state_file="$PACKAGES_STATE_DIR/pip3.freeze.txt"
  [[ -f "$state_file" ]] || return 0
  command -v pip3 >/dev/null 2>&1 || return 0

  pip3 install -r "$state_file" >/dev/null 2>&1 || warn "pip3 restore encountered failures"
  log "pip3 packages restore attempted"
}

restore_pipx_packages() {
  local state_file="$PACKAGES_STATE_DIR/pipx.list.txt"
  [[ -f "$state_file" ]] || return 0
  command -v pipx >/dev/null 2>&1 || return 0

  local pkg
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    pipx install --force "$pkg" >/dev/null 2>&1 || warn "pipx restore failed for $pkg"
  done < <(awk '/^package / {print $2}' "$state_file" | sort -u)

  log "pipx packages restore attempted"
}

restore_gem_packages() {
  local state_file="$PACKAGES_STATE_DIR/gem.list.txt"
  [[ -f "$state_file" ]] || return 0
  command -v gem >/dev/null 2>&1 || return 0

  local gem_name
  while IFS= read -r gem_name; do
    [[ -n "$gem_name" ]] || continue
    gem install "$gem_name" --no-document >/dev/null 2>&1 || warn "gem restore failed for $gem_name"
  done < <(awk -F'[ (]' '/^[A-Za-z0-9_.-]+ \(/ && $0 !~ /\(default/ {print $1}' "$state_file" | sort -u)

  log "gem packages restore attempted"
}

restore_cargo_packages() {
  local state_file="$PACKAGES_STATE_DIR/cargo.install.txt"
  [[ -f "$state_file" ]] || return 0
  command -v cargo >/dev/null 2>&1 || return 0

  local crate
  while IFS= read -r crate; do
    [[ -n "$crate" ]] || continue
    cargo install "$crate" >/dev/null 2>&1 || warn "cargo restore failed for $crate"
  done < <(awk '/^[^[:space:]].* v[0-9].*:$/ {print $1}' "$state_file" | sort -u)

  log "cargo packages restore attempted"
}

restore_extended_packages() {
  restore_mas_packages
  restore_npm_globals
  restore_pip3_packages
  restore_pipx_packages
  restore_gem_packages
  restore_cargo_packages
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

  verify_machine_state_coverage
  apply_machine_state_defaults
  restore_preferences_snapshot
  restore_dock_finder_snapshot
  restore_user_launchagents
  restore_system_launchd
  restore_system_state
  log "captured machine-state restored"

  log "installing packages from Brewfile"
  brew bundle --file "$DOTFILES_DIR/Brewfile"
  restore_extended_packages
  log "package install completed"

  brew doctor
  brew --version
  ls -l "$DOTFILES_DIR"
  log "dotfiles setup completed"
}

main "$@"
