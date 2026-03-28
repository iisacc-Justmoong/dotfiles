#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MACOS_DIR="$DOTFILES_DIR/macOS"

ensure_link() {
  local target_path="$1"
  local link_path="$2"

  if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
    if [[ -L "$link_path" && ! -e "$link_path" ]]; then
      rm -f "$link_path"
    fi
    printf '[symlink][warn] target missing, skipped: %s -> %s\n' "$link_path" "$target_path" >&2
    return 0
  fi

  ln -sfn "$target_path" "$link_path"
}

cleanup_broken_link() {
  local link_path="$1"

  if [[ -L "$link_path" && ! -e "$link_path" ]]; then
    rm -f "$link_path"
    printf '[symlink][warn] removed broken link: %s\n' "$link_path" >&2
  fi
}

ensure_link "$DOTFILES_DIR/.config" "$HOME/.config"
cleanup_broken_link "$HOME/.oh-my-zsh"

ensure_link "$MACOS_DIR/shell/.zshrc" "$HOME/.zshrc"
ensure_link "$MACOS_DIR/shell/.zshenv" "$HOME/.zshenv"
ensure_link "$MACOS_DIR/shell/.zprofile" "$HOME/.zprofile"
ensure_link "$MACOS_DIR/shell/.zlogin" "$HOME/.zlogin"
ensure_link "$MACOS_DIR/shell/.profile" "$HOME/.profile"

ensure_link "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
ensure_link "$DOTFILES_DIR/.gitignore" "$HOME/.gitignore"
ensure_link "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"
