# dotfiles

## For macOS

- Fresh-machine bootstrap:
- `bash -lc "$(curl -fsSL https://raw.githubusercontent.com/iisacc-Justmoong/dotfiles/master/Scripts/bootstrap-dotfiles.sh)"`
- The bootstrap script installs Xcode Command Line Tools when needed, clones the repository into `~/.dotfiles`, and then runs `macOS/Setup.sh`.
- Override variables when needed: `DOTFILES_REPO_URL`, `DOTFILES_BRANCH`, `DOTFILES_DIR`.
- Setup entrypoint: `macOS/Setup.sh`
- Runtime and maintenance scripts: `Scripts/`
- Preserved machine snapshot: `macOS/machine-state/`

## Shell environment

- `.zshenv` owns reusable development paths for every zsh invocation.
- It conditionally exposes Homebrew, Qt, OpenJDK, Emscripten, `.NET`, and local `.local` CMake packages.
- `.local/LVRS/platforms/macos` is treated as the host LVRS prefix for CMake, QML, plugin, include, and library paths.
- Lowercase `.local` packages such as `iiPaintEngine`, `iiXml`, and `iiHtmlBlock` are exposed as local library prefixes.
- `.zshrc` only sets interactive shell behavior and guards optional Android SDK paths so missing legacy installs do not leak into the environment.
