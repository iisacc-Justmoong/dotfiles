# dotfiles

## Windows 실행 검증

`Windows/native_runner.py`는 실행 파일의 실제 Windows 창과 프로세스 ID를 확인하고,
최소 3초 동안 이벤트 루프가 유지된 후 `WM_CLOSE`로 정상 종료하는지 검증한다.
창을 만들지 않고 종료한 프로그램은 성공으로 처리하지 않는다. 보고서와 로그는
프로젝트의 `build/` 아래에 둔다. macOS 설정은 기존 진입점을 사용한다.

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
python -X utf8 Windows/native_runner.py <application.exe> --report build/runtime.json
```

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
