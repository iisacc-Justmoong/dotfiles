#!/bin/sh

path_prepend_if_dir() {
  [ -n "$1" ] && [ -d "$1" ] || return 0

  case ":$PATH:" in
    *:"$1":*) ;;
    *) PATH="$1${PATH:+:$PATH}" ;;
  esac
}

path_prepend_if_dir "$HOME/.local/bin"
path_prepend_if_dir "$HOME/.local/sbin"
path_prepend_if_dir "$HOME/bin"
path_prepend_if_dir "$HOME/.dotnet"
path_prepend_if_dir "$HOME/.dotnet/tools"
path_prepend_if_dir "$HOME/.lmstudio/bin"

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

export PATH
unset -f path_prepend_if_dir 2>/dev/null || true
