#!/bin/zsh
set -euo pipefail

user=$(whoami)

zsh --version

chmod +x ~/.dotfiles/Scripts/*.sh
chmod +x ~/.dotfiles/macOS/Scripts/*.sh
chmod +x ~/.dotfiles/macOS/macos
chmod +x ~/.dotfiles/macOS/shell/symlink.sh

xcode-select --install >/dev/null 2>&1 || true
~/.dotfiles/macOS/Scripts/install_homebrew.sh
echo "Homebrew installed"

~/.dotfiles/macOS/shell/symlink.sh
echo "Symlink dir $user dir"

mkdir -p ~/Library/LaunchAgents
~/.dotfiles/macOS/Scripts/launchctl.sh
echo "Apply launchd"

~/.dotfiles/macOS/macos
echo "Apply macOS Preference "

echo "Start Install All Required Packages"
brew bundle --file ~/.dotfiles/Brewfile
~/.dotfiles/Scripts/machine-state-backup.sh
echo "All Package Installed"

brew doctor
brew --version
ls -l ~/.dotfiles
