#!/bin/bash

echo "install Homebrew"

if command -v brew >/dev/null 2>&1; then
    echo "Homebrew is alrady exist"
    brew --version
    exit 0
fi

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

BREW_PATH="/opt/homebrew/bin/brew"

if [ -f "$BREW_PATH" ]; then
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
    else
        SHELL_PROFILE="$HOME/.profile"
    fi

    echo "export PATH=\"/opt/homebrew/bin:\$PATH\"" >> "$SHELL_PROFILE"
    source "$SHELL_PROFILE"
    echo "Homebrew install success"
    brew --version
else
    echo "Homebrew install failed"
    exit 1
fi