#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
SHELL_DIR="${DOTFILES_DIR}/macOS/shell"
BREWFILE="${DOTFILES_DIR}/Brewfile"

ok_count=0
warn_count=0
fail_count=0

ok() {
  ok_count=$((ok_count + 1))
  printf '[OK] %s\n' "$1"
}

warn() {
  warn_count=$((warn_count + 1))
  printf '[WARN] %s\n' "$1"
}

fail() {
  fail_count=$((fail_count + 1))
  printf '[FAIL] %s\n' "$1"
}

check_shell_link() {
  local filename="$1"
  local home_path="$HOME/$filename"
  local expected_target="$SHELL_DIR/$filename"
  local link_target

  if [[ ! -e "$home_path" ]]; then
    fail "$home_path is missing"
    return
  fi

  if [[ ! -L "$home_path" ]]; then
    warn "$home_path is not a symlink"
    return
  fi

  link_target="$(readlink "$home_path")"
  if [[ "$link_target" == "$expected_target" ]]; then
    ok "$filename -> $link_target"
  else
    warn "$filename points to $link_target (expected $expected_target)"
  fi
}

printf '=== Shell Link Integrity ===\n'
for shell_file in .zshenv .zprofile .zshrc .zlogin .profile; do
  check_shell_link "$shell_file"
done

printf '\n=== Core Toolchain Availability ===\n'
for command_name in brew git gh python3 pip3 node npm go cargo cmake ninja qmake qtpaths; do
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  else
    warn "$command_name is not available"
  fi
done

if command -v brew >/dev/null 2>&1 && [[ -f "$BREWFILE" ]]; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  awk -F'"' '/^brew "/{print $2}' "$BREWFILE" | sort -u >"$tmpdir/brewfile.formula"
  awk -F'"' '/^cask "/{print $2}' "$BREWFILE" | sort -u >"$tmpdir/brewfile.cask"
  brew list --formula | sort -u >"$tmpdir/installed.formula"
  brew list --cask | sort -u >"$tmpdir/installed.cask"

  comm -23 "$tmpdir/brewfile.formula" "$tmpdir/installed.formula" >"$tmpdir/missing.formula"
  comm -23 "$tmpdir/brewfile.cask" "$tmpdir/installed.cask" >"$tmpdir/missing.cask"
  comm -13 "$tmpdir/brewfile.formula" "$tmpdir/installed.formula" >"$tmpdir/extra.formula"
  comm -13 "$tmpdir/brewfile.cask" "$tmpdir/installed.cask" >"$tmpdir/extra.cask"

  missing_formula_count="$(wc -l <"$tmpdir/missing.formula" | tr -d ' ')"
  missing_cask_count="$(wc -l <"$tmpdir/missing.cask" | tr -d ' ')"
  extra_formula_count="$(wc -l <"$tmpdir/extra.formula" | tr -d ' ')"
  extra_cask_count="$(wc -l <"$tmpdir/extra.cask" | tr -d ' ')"

  printf '\n=== Brewfile Drift ===\n'
  if [[ "$missing_formula_count" -eq 0 && "$missing_cask_count" -eq 0 ]]; then
    ok "Brewfile required entries are all installed"
  else
    warn "Missing formula: $missing_formula_count, missing cask: $missing_cask_count"
    [[ "$missing_formula_count" -gt 0 ]] && sed -n '1,20p' "$tmpdir/missing.formula"
    [[ "$missing_cask_count" -gt 0 ]] && sed -n '1,20p' "$tmpdir/missing.cask"
  fi

  if [[ "$extra_formula_count" -eq 0 && "$extra_cask_count" -eq 0 ]]; then
    ok "Installed packages match Brewfile scope"
  else
    warn "Extra formula: $extra_formula_count, extra cask: $extra_cask_count"
    [[ "$extra_formula_count" -gt 0 ]] && sed -n '1,20p' "$tmpdir/extra.formula"
    [[ "$extra_cask_count" -gt 0 ]] && sed -n '1,20p' "$tmpdir/extra.cask"
  fi
else
  warn "Skipping Brewfile drift check (brew or Brewfile missing)"
fi

printf '\n=== Zsh Environment Snapshot ===\n'
if command -v zsh >/dev/null 2>&1; then
  env -i HOME="$HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" SHELL="$(command -v zsh)" \
    "$(command -v zsh)" -c 'printf "QT_PREFIX=%s\nLVRS_PREFIX=%s\nJAVA_HOME=%s\nCMAKE_PREFIX_PATH=%s\n" "$QT_PREFIX" "$LVRS_PREFIX" "$JAVA_HOME" "$CMAKE_PREFIX_PATH"'
  ok "zsh clean environment probe completed"
else
  fail "zsh is not available"
fi

printf '\n=== Summary ===\n'
printf 'OK=%d WARN=%d FAIL=%d\n' "$ok_count" "$warn_count" "$fail_count"

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi
