#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# Home top-level history and dump files that are safe to regenerate.
for pattern in \
  ".zcompdump*" \
  ".python_history" \
  ".node_repl_history" \
  ".lesshst" \
  ".wget-hsts" \
  ".DS_Store"; do
  find "$HOME" -maxdepth 1 -type f -name "$pattern" -delete
done

# Generated files inside dotfiles repository.
if [[ -d "$DOTFILES_DIR" ]]; then
  find "$DOTFILES_DIR" -type f -name ".DS_Store" -not -path "$DOTFILES_DIR/.git/*" -delete
  find "$DOTFILES_DIR/macOS/shell" -maxdepth 1 -type f -name "*.pysave" -delete 2>/dev/null || true
  find "$DOTFILES_DIR/.config/.android/cache" -mindepth 1 -delete 2>/dev/null || true
  find "$DOTFILES_DIR/.config/.android" -maxdepth 1 -type f -name "*.lock" -delete 2>/dev/null || true
fi
