# dotfiles

## For macOS

- Fresh-machine bootstrap:
- `bash -lc "$(curl -fsSL https://raw.githubusercontent.com/iisacc-Justmoong/dotfiles/master/Scripts/bootstrap-dotfiles.sh)"`
- The bootstrap script installs Xcode Command Line Tools when needed, clones the repository into `~/.dotfiles`, and then runs `macOS/Setup.sh`.
- Override variables when needed: `DOTFILES_REPO_URL`, `DOTFILES_BRANCH`, `DOTFILES_DIR`.
- Setup entrypoint: `macOS/Setup.sh`
- Runtime and maintenance scripts: `Scripts/`
- Preserved machine snapshot: `macOS/machine-state/`
