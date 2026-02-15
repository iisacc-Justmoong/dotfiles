#!/bin/zsh

[[ -o interactive && -t 1 ]] || return 0

command -v neofetch >/dev/null 2>&1 && neofetch
command -v fortune >/dev/null 2>&1 && fortune
