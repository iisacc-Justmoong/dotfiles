#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MACOS_DIR="$DOTFILES_DIR/macOS"

ln -sf "$DOTFILES_DIR/.config" "$HOME/.config"
ln -sf "$MACOS_DIR/shell/.oh-my-zsh" "$HOME/.oh-my-zsh"

ln -sf "$MACOS_DIR/shell/.zshrc" "$HOME/.zshrc"
ln -sf "$MACOS_DIR/shell/.zshenv" "$HOME/.zshenv"
ln -sf "$MACOS_DIR/shell/.zprofile" "$HOME/.zprofile"
ln -sf "$MACOS_DIR/shell/.zlogin" "$HOME/.zlogin"
ln -sf "$MACOS_DIR/shell/.profile" "$HOME/.profile"

ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES_DIR/.gitignore" "$HOME/.gitignore"
ln -sf "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"
