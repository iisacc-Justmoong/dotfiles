#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/iisacc-Justmoong/dotfiles.git}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-master}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
SUDO_READY=0

log() {
  printf '[bootstrap] %s\n' "$1"
}

warn() {
  printf '[bootstrap][warn] %s\n' "$1"
}

fail() {
  printf '[bootstrap][error] %s\n' "$1" >&2
  exit 1
}

ensure_sudo_session() {
  if [[ "$SUDO_READY" -eq 1 ]]; then
    return 0
  fi

  if sudo -n true >/dev/null 2>&1; then
    SUDO_READY=1
    return 0
  fi

  log "sudo authentication required"
  sudo -v || fail "sudo authentication failed"
  SUDO_READY=1
}

wait_for_xcode_clt() {
  local retries=0

  until xcode-select -p >/dev/null 2>&1; do
    retries=$((retries + 1))
    if [[ "$retries" -ge 120 ]]; then
      fail "Xcode Command Line Tools installation timeout"
    fi
    sleep 5
  done
}

install_xcode_clt_with_softwareupdate() {
  command -v softwareupdate >/dev/null 2>&1 || return 1

  local marker="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  local label=""

  touch "$marker"
  label="$(
    softwareupdate -l 2>/dev/null \
      | awk '/^\* Label: Command Line Tools/ { sub(/^\* Label: /, ""); print }' \
      | tail -n 1
  )"
  rm -f "$marker"

  [[ -n "$label" ]] || return 1

  ensure_sudo_session
  sudo softwareupdate -i "$label" --verbose
  sudo xcode-select --switch /Library/Developer/CommandLineTools >/dev/null 2>&1 || true
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools already installed"
    return 0
  fi

  log "installing Xcode Command Line Tools"
  if ! install_xcode_clt_with_softwareupdate; then
    warn "softwareupdate-based installation unavailable, falling back to xcode-select --install"
    xcode-select --install >/dev/null 2>&1 || true
  fi

  wait_for_xcode_clt
  log "Xcode Command Line Tools ready"
}

ensure_git() {
  command -v git >/dev/null 2>&1 || fail "git is unavailable after Xcode Command Line Tools installation"
}

ensure_dotfiles_checkout() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    local remote_url=""
    remote_url="$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null || true)"
    if [[ -n "$remote_url" ]] && [[ "$remote_url" != "$DOTFILES_REPO_URL" ]] && [[ "$remote_url" != "${DOTFILES_REPO_URL%.git}" ]]; then
      warn "existing checkout uses a different origin: $remote_url"
    fi
    log "dotfiles checkout already exists: $DOTFILES_DIR"
    return 0
  fi

  if [[ -e "$DOTFILES_DIR" ]] && [[ -n "$(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    fail "target directory exists and is not an empty git checkout: $DOTFILES_DIR"
  fi

  mkdir -p "$(dirname "$DOTFILES_DIR")"
  log "cloning $DOTFILES_REPO_URL ($DOTFILES_BRANCH) into $DOTFILES_DIR"
  git clone --branch "$DOTFILES_BRANCH" "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
}

run_setup() {
  local setup_script="$DOTFILES_DIR/macOS/Setup.sh"
  [[ -f "$setup_script" ]] || fail "setup script missing: $setup_script"

  chmod +x "$setup_script"
  log "running $setup_script"
  DOTFILES_DIR="$DOTFILES_DIR" "$setup_script"
}

main() {
  log "bootstrap start"
  ensure_xcode_clt
  ensure_git
  ensure_dotfiles_checkout
  run_setup
  log "bootstrap completed"
}

main "$@"
