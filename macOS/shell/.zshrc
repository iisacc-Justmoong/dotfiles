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
  "$repo/Scripts/capture-dock-state.sh" || return 1
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

# Android SDK/NDK
_zshrc_path_prepend_unique() {
  local dir_path="$1"
  [[ -n "$dir_path" && -d "$dir_path" ]] || return 0

  case ":$PATH:" in
    *":$dir_path:"*) ;;
    *) export PATH="$dir_path${PATH:+:$PATH}" ;;
  esac
}

android_sdk_root="$HOME/Library/Android/sdk"
if [[ -d "$android_sdk_root" ]]; then
  export ANDROID_SDK_ROOT="$android_sdk_root"
  export ANDROID_HOME="$android_sdk_root"

  _zshrc_path_prepend_unique "$ANDROID_HOME/platform-tools"
  _zshrc_path_prepend_unique "$ANDROID_HOME/cmdline-tools/latest/bin"
  _zshrc_path_prepend_unique "$ANDROID_HOME/emulator"

  typeset -a android_ndk_candidates
  android_ndk_candidates=( "$ANDROID_HOME"/ndk/*(Nn-/) )
  if (( ${#android_ndk_candidates[@]} )); then
    export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-${android_ndk_candidates[-1]}}"
    export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_NDK_ROOT}"
    export CMAKE_ANDROID_NDK="${CMAKE_ANDROID_NDK:-$ANDROID_NDK_ROOT}"
  fi
  unset android_ndk_candidates
fi
unset android_sdk_root
unset -f _zshrc_path_prepend_unique

# Emscripten SDK
export EMSDK="$HOME/emsdk"
if [[ -f "$EMSDK/emsdk_env.sh" ]]; then
  export EMSDK_QUIET=1
  source "$EMSDK/emsdk_env.sh" >/dev/null
fi

# OpenClaw Completion
if [[ -r "$HOME/.openclaw/completions/openclaw.zsh" ]]; then
  source "$HOME/.openclaw/completions/openclaw.zsh"
fi
