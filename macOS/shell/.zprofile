#!/bin/zsh

if [[ -x "${HOMEBREW_PREFIX:-}/bin/brew" ]]; then
  eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv 2>/dev/null)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)"
fi

if [[ -d /usr/local/kde4 ]]; then
  export KDEDIRS="${KDEDIRS:+$KDEDIRS:}$HOME/Library/Preferences/KDE:/usr/local/kde4"
  export PATH="/usr/local/kde4/bin:$PATH"
  export DYLD_LIBRARY_PATH="/usr/local/kde4/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
  if command -v launchctl >/dev/null 2>&1; then
    launchctl setenv DYLD_LIBRARY_PATH "$DYLD_LIBRARY_PATH" >/dev/null 2>&1
  fi
  export XDG_DATA_HOME="$HOME/Library/Preferences/KDE/share"
  export XDG_DATA_DIRS="/usr/local/kde4/share:/usr/local/share:/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
fi

if [[ -f "$HOME/.zprofile.local" ]]; then
  source "$HOME/.zprofile.local"
fi
