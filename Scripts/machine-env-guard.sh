#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
STATE_DIR="${STATE_DIR:-$DOTFILES_DIR/machine-state}"
RUNTIME_DIR="$STATE_DIR/runtime"
BACKUP_DIR="$RUNTIME_DIR/pre-guard-backups"
LOG_FILE="$RUNTIME_DIR/dev-env-guard.log"
DOCTOR_LOG="$RUNTIME_DIR/dev-env-doctor.last.log"
DOCTOR_MARKER="$RUNTIME_DIR/last_doctor_epoch"
METADATA_FILE="$STATE_DIR/metadata.env"
NOW_TS="$(date '+%Y-%m-%d %H:%M:%S')"
TODAY="$(date '+%Y-%m-%d')"

mkdir -p "$RUNTIME_DIR" "$BACKUP_DIR"
exec >>"$LOG_FILE" 2>&1

echo "=== [$NOW_TS] machine-env-guard start ==="

backup_before_replace() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  local base_name
  base_name="$(basename "$path")"
  local backup_path="$BACKUP_DIR/${base_name}.$(date '+%Y%m%d-%H%M%S').bak"
  mv "$path" "$backup_path"
  echo "[INFO] moved existing path to backup: $path -> $backup_path"
}

ensure_symlink() {
  local link_path="$1"
  local target_path="$2"

  if [[ ! -e "$target_path" ]]; then
    echo "[WARN] target does not exist: $target_path"
    return 0
  fi

  if [[ -L "$link_path" ]]; then
    local current_target
    current_target="$(readlink "$link_path")"
    if [[ "$current_target" == "$target_path" ]]; then
      return 0
    fi
    backup_before_replace "$link_path"
  elif [[ -e "$link_path" ]]; then
    backup_before_replace "$link_path"
  fi

  ln -sfn "$target_path" "$link_path"
  echo "[OK] symlink enforced: $link_path -> $target_path"
}

run_clean_generated() {
  local cleaner="$DOTFILES_DIR/Scripts/machine-clean-generated.sh"
  if [[ -x "$cleaner" ]]; then
    "$cleaner"
    echo "[OK] generated-file cleanup completed"
  else
    echo "[WARN] cleaner script missing: $cleaner"
  fi
}

run_backup_if_needed() {
  local last_backup_date=""
  if [[ -f "$METADATA_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$METADATA_FILE" || true
    last_backup_date="${BACKUP_DATE:-}"
  fi

  if [[ "$last_backup_date" == "$TODAY" ]]; then
    echo "[INFO] daily backup already done today: $TODAY"
    return 0
  fi

  local backup_script="$DOTFILES_DIR/Scripts/machine-state-backup.sh"
  if [[ -x "$backup_script" ]]; then
    "$backup_script"
    echo "[OK] machine-state backup executed from guard"
  else
    echo "[WARN] backup script missing: $backup_script"
  fi
}

run_doctor_periodically() {
  local now_epoch
  now_epoch="$(date +%s)"
  local last_epoch=0
  local doctor_interval=21600

  if [[ -f "$DOCTOR_MARKER" ]]; then
    last_epoch="$(cat "$DOCTOR_MARKER" 2>/dev/null || echo 0)"
  fi

  if (( now_epoch - last_epoch < doctor_interval )); then
    echo "[INFO] doctor interval not reached"
    return 0
  fi

  if [[ -x "$DOTFILES_DIR/Scripts/dev-env-doctor.sh" ]]; then
    PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$PATH" \
      "$DOTFILES_DIR/Scripts/dev-env-doctor.sh" >"$DOCTOR_LOG" 2>&1 || true
    echo "$now_epoch" >"$DOCTOR_MARKER"
    echo "[OK] dev-env doctor ran (log: $DOCTOR_LOG)"
  else
    echo "[WARN] doctor script missing"
  fi
}

repair_git_permission_if_possible() {
  local git_dir="$DOTFILES_DIR/.git"
  [[ -d "$git_dir" ]] || return 0

  local root_owned_count
  root_owned_count="$(find "$git_dir" -user root -print | wc -l | tr -d ' ')"
  if [[ "$root_owned_count" == "0" ]]; then
    echo "[OK] git ownership healthy"
    return 0
  fi

  echo "[WARN] root-owned paths detected in .git: $root_owned_count"
  if sudo -n true >/dev/null 2>&1; then
    sudo chown -R "$(id -un):$(id -gn)" "$git_dir" && echo "[OK] auto-repaired .git ownership"
  else
    echo "[WARN] cannot auto-repair .git ownership (sudo non-interactive unavailable)"
  fi
}

ensure_symlink "$HOME/.config" "$DOTFILES_DIR/.config"
ensure_symlink "$HOME/.zshenv" "$DOTFILES_DIR/macOS/shell/.zshenv"
ensure_symlink "$HOME/.zprofile" "$DOTFILES_DIR/macOS/shell/.zprofile"
ensure_symlink "$HOME/.zshrc" "$DOTFILES_DIR/macOS/shell/.zshrc"
ensure_symlink "$HOME/.zlogin" "$DOTFILES_DIR/macOS/shell/.zlogin"
ensure_symlink "$HOME/.profile" "$DOTFILES_DIR/macOS/shell/.profile"
ensure_symlink "$HOME/.gitconfig" "$DOTFILES_DIR/.gitconfig"
ensure_symlink "$HOME/.gitignore" "$DOTFILES_DIR/.gitignore"
ensure_symlink "$HOME/.gitignore_global" "$DOTFILES_DIR/.gitignore_global"

run_clean_generated
run_backup_if_needed
run_doctor_periodically
repair_git_permission_if_possible

echo "=== [$NOW_TS] machine-env-guard end ==="
