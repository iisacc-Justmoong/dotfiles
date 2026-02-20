#!/bin/zsh

[[ -o interactive ]] || return 0

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="${ZSH_THEME:-jonathan}"
plugins=(git)

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

for zsh_plugin in \
  "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
  [[ -r "$zsh_plugin" ]] && source "$zsh_plugin"
done
unset zsh_plugin

if command -v nvim >/dev/null 2>&1; then
  export EDITOR="${EDITOR:-nvim}"
  export VISUAL="${VISUAL:-nvim}"
elif command -v vim >/dev/null 2>&1; then
  export EDITOR="${EDITOR:-vim}"
  export VISUAL="${VISUAL:-vim}"
else
  export EDITOR="${EDITOR:-vi}"
  export VISUAL="${VISUAL:-vi}"
fi

HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=200000
SAVEHIST=200000
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS SHARE_HISTORY EXTENDED_HISTORY INC_APPEND_HISTORY

alias python='python3'
alias pip='pip3'
alias ll='ls -alh'
alias la='ls -A'
alias l='ls -CF'
alias brew-up='brew update && brew upgrade && brew cleanup'
alias dot='cd "$HOME/.dotfiles"'
alias env-doctor="$HOME/.dotfiles/Scripts/dev-env-doctor.sh"

b() {
  command -v brew >/dev/null 2>&1 || return 1
  brew update && brew upgrade && brew cleanup
  echo "Check Complete at $(date)." >>"$HOME/checkbrew.log"
}

dotsync() {
  local repo="$HOME/.dotfiles"
  [[ -d "$repo/.git" ]] || return 1
  git -C "$repo" add -A
  git -C "$repo" commit -m "Sync at: $(date '+%Y-%m-%d %H:%M:%S')" || return 0
  git -C "$repo" push
}

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

export DIST_CERT_SHA="${DIST_CERT_SHA:-<SHA1_PLACEHOLDER>}"

if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi

# LVRS Android SDK/NDK
export ANDROID_SDK_ROOT="/Users/ymy/Library/Android/sdk"
export ANDROID_HOME="/Users/ymy/Library/Android/sdk"
export ANDROID_NDK_ROOT="/Users/ymy/Library/Android/sdk/ndk/29.0.14206865"
export ANDROID_NDK_HOME="/Users/ymy/Library/Android/sdk/ndk/29.0.14206865"
export CMAKE_ANDROID_NDK="/Users/ymy/Library/Android/sdk/ndk/29.0.14206865"

# OpenClaw Completion
source "/Users/ymy/.openclaw/completions/openclaw.zsh"
