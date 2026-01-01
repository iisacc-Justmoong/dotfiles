#!/bin/zsh

rm -rf ~/.cache
rm -rf ~/.cups
rm -rf ~/.npm
rm -rf ~/.gradle
rm -rf ~/.bundle
rm -rf ~/.gk
rm -rf ~/.ServiceHub
rm -rf ~/.rbenv
rm -rf ~/.matplotlib
rm -rf ~/.DDLocalBackups
rm -rf ~/.DDPreview
rm -rf ~/.vhdl_ls.toml
rm -rf ~/.teroshdl2_prj.json
rm -rf ~/.python_history
rm -rf ~/.zsh_sessions
rm -rf ~/.zsh_history
rm -rf ~/.lesshst
rm -rf ~/.node_repl_history
rm -rf ~/.zshrc.backup
rm -rf ~/.CFUserTextEncoding
rm -rf ~/.wget-hsts
rm -rf ~/.zcompdump
rm -rf ~/.zcompdump-Mac Studio-5.9
rm -rf ~/.nuget
rm -rf ~/.wget-hsts
rm -rf ~/.DS_Store

brew cleanup
brew update
brew upgrade
brew cleanup

cd ~/.dotfiles/
sudo git add .
sudo git commit -m "Fixed at: $(date '+%Y-%m-%d %H:%M:%S')"
sudo git push
cd

cp ~/Library/Preferences/com.apple.dock.plist ~/.dotfiles/macOS/com.apple.dock.plist
echo "System Launch Cleanup has done $(date '+%Y-%m-%d %H:%M:%S')" >> ~/.Logs/LanchTasks.log

osascript -e 'tell application "iTerm2" to tell current tab to close'
