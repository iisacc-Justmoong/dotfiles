#!/bin/zsh
set -euo pipefail

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
MACOS_DIR="$DOTFILES_DIR/macOS"
SCRIPTS_DIR="$DOTFILES_DIR/Scripts"
STATE_DIR="$MACOS_DIR/machine-state"
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
  local file_path="$1"
  [[ -f "$file_path" ]] || fail "required file missing: $file_path"
}

upsert_plist_string() {
  local plist="$1"
  local key_path="$2"
  local value="$3"
  local parent_path="${key_path%:*}"

  /usr/libexec/PlistBuddy -c "Set $key_path $value" "$plist" >/dev/null 2>&1 && return 0
  /usr/libexec/PlistBuddy -c "Print $parent_path" "$plist" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add $parent_path dict" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add $key_path string $value" "$plist" >/dev/null 2>&1 || true
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
  local -a entries

  [[ -d "$dir" ]] || return 1
  entries=( "$dir"/*(DN) )
  (( ${#entries[@]} > 0 ))
}

count_matching_files() {
  local dir="$1"
  local pattern="$2"
  local -a matches

  [[ -d "$dir" ]] || {
    printf '0'
    return 0
  }

  matches=( "$dir"/${~pattern}(DN.) )
  printf '%s' "${#matches[@]}"
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
    rsync -a "$src"/ "$dst"/ >/dev/null 2>&1 || {
      warn "partial copy skipped for $src -> $dst"
      return 0
    }
    return 0
  fi

  local -a entries
  local entry_path
  entries=( "$src"/*(DN) )

  for entry_path in "${entries[@]}"; do
    cp -R "$entry_path" "$dst"/ >/dev/null 2>&1 || warn "copy skipped for $entry_path"
  done
}

copy_dir_contents_sudo() {
  local src="$1"
  local dst="$2"

  [[ -d "$src" ]] || return 0
  ensure_sudo_session
  sudo mkdir -p "$dst"

  if command -v rsync >/dev/null 2>&1; then
    sudo rsync -a "$src"/ "$dst"/ >/dev/null 2>&1 || {
      warn "partial sudo copy skipped for $src -> $dst"
      return 0
    }
    return 0
  fi

  local -a entries
  local entry_path
  entries=( "$src"/*(DN) )

  for entry_path in "${entries[@]}"; do
    sudo cp -R "$entry_path" "$dst"/ >/dev/null 2>&1 || warn "sudo copy skipped for $entry_path"
  done
}

restore_plist_via_defaults() {
  local src_plist="$1"
  local target_domain="$2"

  [[ -f "$src_plist" ]] || return 1

  if defaults import "$target_domain" "$src_plist" >/dev/null 2>&1; then
    return 0
  fi

  warn "defaults import skipped for $target_domain"
  return 1
}

grant_exec_permissions() {
  chmod +x "$SCRIPTS_DIR"/*.sh
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

ensure_oh_my_zsh() {
  local omz_dir="$HOME/.oh-my-zsh"
  local omz_repo="https://github.com/ohmyzsh/ohmyzsh.git"

  if [[ -r "$omz_dir/oh-my-zsh.sh" ]]; then
    log "oh-my-zsh already available"
    return 0
  fi

  if [[ -L "$omz_dir" && ! -e "$omz_dir" ]]; then
    rm -f "$omz_dir"
  fi

  if [[ -e "$omz_dir" && ! -d "$omz_dir" ]]; then
    warn "cannot install oh-my-zsh because $omz_dir exists and is not a directory"
    return 0
  fi

  log "installing oh-my-zsh"
  if git clone --depth=1 "$omz_repo" "$omz_dir" >/dev/null 2>&1; then
    log "oh-my-zsh installed"
    return 0
  fi

  warn "oh-my-zsh installation failed; shell will continue without it"
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

  local state_path
  for state_path in "${required_paths[@]}"; do
    if [[ -d "$state_path" ]]; then
      log "machine-state source found: $state_path"
    else
      warn "machine-state source missing: $state_path"
    fi
  done

  [[ -f "$SUMMARY_FILE" ]] && log "machine-state summary found: $SUMMARY_FILE"
}

apply_machine_state_defaults() {
  if [[ -f "$DEFAULTS_APPLY_SCRIPT" ]]; then
    log "applying captured defaults from machine-state"
    if ! bash "$DEFAULTS_APPLY_SCRIPT"; then
      warn "captured defaults restore encountered protected or unavailable domains"
    fi
  else
    warn "captured defaults script not found, skipping"
  fi
}

restore_dock_finder_snapshot() {
  local dock_snapshot="$PLIST_STATE_DIR/com.apple.dock.snapshot.plist"
  local finder_snapshot="$PLIST_STATE_DIR/com.apple.finder.snapshot.plist"
  local dock_export="$PLIST_STATE_DIR/com.apple.dock.export.plist"
  local finder_export="$PLIST_STATE_DIR/com.apple.finder.export.plist"
  local dock_target="$HOME/Library/Preferences/com.apple.dock.plist"
  local finder_target="$HOME/Library/Preferences/com.apple.finder.plist"

  log "restoring Dock/Finder snapshot"

  if [[ -f "$dock_snapshot" ]]; then
    restore_plist_via_defaults "$dock_snapshot" "$dock_target" || true
  elif [[ -f "$dock_export" ]]; then
    restore_plist_via_defaults "$dock_export" "$dock_target" || true
  fi

  if [[ -f "$finder_snapshot" ]]; then
    restore_plist_via_defaults "$finder_snapshot" "$finder_target" || true
  elif [[ -f "$finder_export" ]]; then
    restore_plist_via_defaults "$finder_export" "$finder_target" || true
  fi

  killall Dock >/dev/null 2>&1 || true
  killall Finder >/dev/null 2>&1 || true
}

restore_preferences_snapshot() {
  local user_src="$PREFERENCES_STATE_DIR/user"
  local byhost_src="$PREFERENCES_STATE_DIR/byhost"
  local user_dst="$HOME/Library/Preferences"
  local byhost_dst="$HOME/Library/Preferences/ByHost"
  local plist_path target imported_count=0 skipped_count=0 processed_count=0
  local user_count byhost_count total_count
  local -a user_plists byhost_plists

  user_count="$(count_matching_files "$user_src" '*.plist')"
  byhost_count="$(count_matching_files "$byhost_src" '*.plist')"
  total_count=$((user_count + byhost_count))

  if [[ "$total_count" -eq 0 ]]; then
    warn "preferences snapshot not found, skipping"
    return 0
  fi

  log "restoring preferences snapshot (user=$user_count byhost=$byhost_count total=$total_count)"
  mkdir -p "$user_dst" "$byhost_dst"
  user_plists=( "$user_src"/*.plist(DN.) )
  byhost_plists=( "$byhost_src"/*.plist(DN.) )

  if [[ "$user_count" -gt 0 ]]; then
    for plist_path in "${user_plists[@]}"; do
      target="$user_dst/${plist_path:t}"
      if restore_plist_via_defaults "$plist_path" "$target"; then
        imported_count=$((imported_count + 1))
      else
        skipped_count=$((skipped_count + 1))
      fi
      processed_count=$((processed_count + 1))
      if (( processed_count % 50 == 0 || processed_count == total_count )); then
        log "preferences restore progress $processed_count/$total_count"
      fi
    done
  fi

  if [[ "$byhost_count" -gt 0 ]]; then
    for plist_path in "${byhost_plists[@]}"; do
      target="$byhost_dst/${plist_path:t}"
      if restore_plist_via_defaults "$plist_path" "$target"; then
        imported_count=$((imported_count + 1))
      else
        skipped_count=$((skipped_count + 1))
      fi
      processed_count=$((processed_count + 1))
      if (( processed_count % 50 == 0 || processed_count == total_count )); then
        log "preferences restore progress $processed_count/$total_count"
      fi
    done
  fi

  killall cfprefsd >/dev/null 2>&1 || true
  if [[ "$skipped_count" -gt 0 ]]; then
    warn "preferences snapshot restored with skips (imported=$imported_count skipped=$skipped_count)"
  else
    log "preferences snapshot restored (imported=$imported_count)"
  fi
}

rewrite_user_launchagent_paths() {
  local plist="$1"
  local backup_user_home=""

  if [[ -f "$METADATA_FILE" ]]; then
    local backup_user=""
    # shellcheck disable=SC1090
    source "$METADATA_FILE" || true
    backup_user="${BACKUP_USER:-}"
    if [[ -n "$backup_user" && "$backup_user" != "unknown" ]]; then
      backup_user_home="/Users/$backup_user"
    fi
  fi

  plutil -convert xml1 "$plist" >/dev/null 2>&1 || true

  if [[ -n "$backup_user_home" && "$backup_user_home" != "$HOME" ]]; then
    BACKUP_HOME="$backup_user_home" CURRENT_HOME="$HOME" \
      perl -0pi -e 's/\Q$ENV{BACKUP_HOME}\E/\Q$ENV{CURRENT_HOME}\E/g' "$plist"
  fi

  upsert_plist_string "$plist" ":EnvironmentVariables:HOME" "$HOME"
  [[ -n "${TMPDIR:-}" ]] && upsert_plist_string "$plist" ":EnvironmentVariables:TMPDIR" "$TMPDIR"
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
    /usr/libexec/PlistBuddy -c "Delete :ProgramArguments" "$plist" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments array" "$plist" >/dev/null
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string $script_path" "$plist" >/dev/null
  fi
}

launchd_program_path() {
  local plist="$1"
  /usr/libexec/PlistBuddy -c 'Print :Program' "$plist" 2>/dev/null && return 0
  /usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$plist" 2>/dev/null || true
}

warn_if_launchd_program_missing() {
  local plist="$1"
  local label="$2"
  local program_path=""

  program_path="$(launchd_program_path "$plist")"
  [[ -n "$program_path" ]] || return 0
  [[ -x "$program_path" ]] && return 0

  warn "launch agent executable missing for $label: $program_path"
}

restore_user_launchagents() {
  local src="$LAUNCHD_STATE_DIR/user-LaunchAgents"
  local dst="$HOME/Library/LaunchAgents"
  local uid dst_plist label
  local total_count processed_count=0
  local -a plist_paths

  plist_paths=( "$src"/*.plist(DN.) )
  total_count="${#plist_paths[@]}"

  [[ "$total_count" -gt 0 ]] || {
    warn "user launchagents snapshot not found, skipping"
    return 0
  }

  log "restoring user launchagents (total=$total_count)"
  uid="$(id -u)"
  mkdir -p "$dst"
  copy_dir_contents "$src" "$dst"

  local plist_path
  for plist_path in "${plist_paths[@]}"; do
    dst_plist="$dst/${plist_path:t}"
    [[ -f "$dst_plist" ]] || continue
    rewrite_user_launchagent_paths "$dst_plist"
    rewrite_dotfiles_launchagent_program "$dst_plist"
    launchctl bootout "gui/$uid" "$dst_plist" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$uid" "$dst_plist" >/dev/null 2>&1 || true
    label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$dst_plist" 2>/dev/null || true)"
    [[ -n "$label" ]] && warn_if_launchd_program_missing "$dst_plist" "$label"
    processed_count=$((processed_count + 1))
    log "user launchagents progress $processed_count/$total_count"
  done

  log "user launchagents restored"
}

restore_system_launchd() {
  local src_agents="$LAUNCHD_STATE_DIR/system-LaunchAgents"
  local src_daemons="$LAUNCHD_STATE_DIR/system-LaunchDaemons"
  local launchd_src_path dst_path
  local agents_count daemons_count total_count processed_count=0
  local label
  local -a agent_plists daemon_plists

  agent_plists=( "$src_agents"/*.plist(DN.) )
  daemon_plists=( "$src_daemons"/*.plist(DN.) )
  agents_count="${#agent_plists[@]}"
  daemons_count="${#daemon_plists[@]}"
  total_count=$((agents_count + daemons_count))

  if [[ "$total_count" -eq 0 ]]; then
    warn "system launchd snapshot not found, skipping"
    return 0
  fi

  log "restoring system launchd (agents=$agents_count daemons=$daemons_count total=$total_count)"
  has_entries "$src_agents" && copy_dir_contents_sudo "$src_agents" "/Library/LaunchAgents"
  has_entries "$src_daemons" && copy_dir_contents_sudo "$src_daemons" "/Library/LaunchDaemons"

  if [[ "$agents_count" -gt 0 ]]; then
    for launchd_src_path in "${agent_plists[@]}"; do
      dst_path="/Library/LaunchAgents/${launchd_src_path:t}"
      [[ -f "$dst_path" ]] || continue
      sudo launchctl bootout system "$dst_path" >/dev/null 2>&1 || true
      sudo launchctl bootstrap system "$dst_path" >/dev/null 2>&1 || true
      label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$dst_path" 2>/dev/null || true)"
      [[ -n "$label" ]] && warn_if_launchd_program_missing "$dst_path" "$label"
      processed_count=$((processed_count + 1))
      log "system launchd progress $processed_count/$total_count"
    done
  fi

  if [[ "$daemons_count" -gt 0 ]]; then
    for launchd_src_path in "${daemon_plists[@]}"; do
      dst_path="/Library/LaunchDaemons/${launchd_src_path:t}"
      [[ -f "$dst_path" ]] || continue
      sudo launchctl bootout system "$dst_path" >/dev/null 2>&1 || true
      sudo launchctl bootstrap system "$dst_path" >/dev/null 2>&1 || true
      label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$dst_path" 2>/dev/null || true)"
      [[ -n "$label" ]] && warn_if_launchd_program_missing "$dst_path" "$label"
      processed_count=$((processed_count + 1))
      log "system launchd progress $processed_count/$total_count"
    done
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
  log "restoring captured system state"
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
  require_file "$SCRIPTS_DIR/install_homebrew.sh"
  require_file "$MACOS_DIR/macos"
  require_file "$MACOS_DIR/shell/symlink.sh"

  ensure_dotfiles_home_link
  grant_exec_permissions
  ensure_xcode_clt

  "$SCRIPTS_DIR/install_homebrew.sh"
  log "Homebrew installed"

  ensure_oh_my_zsh

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

  brew doctor || warn "brew doctor reported issues"
  brew --version
  ls -l "$DOTFILES_DIR"
  log "dotfiles setup completed"
}

main "$@"
