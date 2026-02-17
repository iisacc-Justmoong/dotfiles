#!/bin/zsh

_pathvar_prepend_unique() {
  typeset var_name="$1"
  typeset dir_path="$2"

  [[ -n "$var_name" && -n "$dir_path" && -d "$dir_path" ]] || return 0

  typeset current_value="${(P)var_name}"
  case ":$current_value:" in
    *":$dir_path:"*) ;;
    *) typeset -gx "$var_name=$dir_path${current_value:+:$current_value}" ;;
  esac
}

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export LANG="${LANG:-en_US.UTF-8}"

for base_path in \
  "$HOME/.local/bin" \
  "$HOME/.local/sbin" \
  "$HOME/bin" \
  "$HOME/.cargo/bin" \
  "$HOME/go/bin" \
  "$HOME/.lmstudio/bin"; do
  _pathvar_prepend_unique PATH "$base_path"
done

if [[ -z "${HOMEBREW_PREFIX:-}" || ! -d "${HOMEBREW_PREFIX:-}" ]]; then
  for brew_prefix_candidate in /opt/homebrew /usr/local; do
    if [[ -x "$brew_prefix_candidate/bin/brew" ]]; then
      export HOMEBREW_PREFIX="$brew_prefix_candidate"
      break
    fi
  done
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -d "$HOMEBREW_PREFIX" ]]; then
  _pathvar_prepend_unique PATH "$HOMEBREW_PREFIX/bin"
  _pathvar_prepend_unique PATH "$HOMEBREW_PREFIX/sbin"
  _pathvar_prepend_unique PKG_CONFIG_PATH "$HOMEBREW_PREFIX/lib/pkgconfig"
  _pathvar_prepend_unique PKG_CONFIG_PATH "$HOMEBREW_PREFIX/share/pkgconfig"
fi

if [[ -d /opt/local ]]; then
  _pathvar_prepend_unique PATH /opt/local/bin
  _pathvar_prepend_unique PATH /opt/local/sbin
fi

if [[ -z "${JAVA_HOME:-}" ]]; then
  for jdk_candidate in \
    "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/openjdk/libexec/openjdk.jdk/Contents/Home" \
    "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/openjdk"; do
    if [[ -d "$jdk_candidate" ]]; then
      export JAVA_HOME="$jdk_candidate"
      break
    fi
  done
fi

if [[ -n "${JAVA_HOME:-}" && -d "$JAVA_HOME" ]]; then
  _pathvar_prepend_unique PATH "$JAVA_HOME/bin"
fi

export UIFRAMEWORK_PREFIX="${UIFRAMEWORK_PREFIX:-$HOME/.local/UIFramework}"
_pathvar_prepend_unique CMAKE_PREFIX_PATH "$UIFRAMEWORK_PREFIX"

if [[ -z "${QT_PREFIX:-}" || ! -d "${QT_PREFIX:-}" ]]; then
  typeset -a qt_installer_candidates
  qt_installer_candidates=( "$HOME"/Qt/*/macos(Nn-/) )
  if (( ${#qt_installer_candidates[@]} )); then
    export QT_PREFIX="${qt_installer_candidates[-1]}"
  else
    for qt_fallback in \
      "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/qt" \
      "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/qt@6" \
      /usr/local/opt/qt \
      /usr/local/opt/qt@6; do
      if [[ -d "$qt_fallback" ]]; then
        export QT_PREFIX="$qt_fallback"
        break
      fi
    done
  fi
fi

if [[ -n "${QT_PREFIX:-}" && -d "$QT_PREFIX" ]]; then
  export QTDIR="${QTDIR:-$QT_PREFIX}"
  _pathvar_prepend_unique PATH "$QT_PREFIX/bin"
  _pathvar_prepend_unique CMAKE_PREFIX_PATH "$QT_PREFIX"
  _pathvar_prepend_unique QML2_IMPORT_PATH "$QT_PREFIX/qml"
  _pathvar_prepend_unique QT_QML_IMPORT_PATH "$QT_PREFIX/qml"
  _pathvar_prepend_unique QML2_IMPORT_PATH "$QT_PREFIX/lib/qt6/qml"
  _pathvar_prepend_unique QT_QML_IMPORT_PATH "$QT_PREFIX/lib/qt6/qml"
  _pathvar_prepend_unique QT_PLUGIN_PATH "$QT_PREFIX/plugins"
  _pathvar_prepend_unique QT_PLUGIN_PATH "$QT_PREFIX/lib/qt6/plugins"
fi

if [[ -z "${LVRS_PREFIX:-}" || ! -d "${LVRS_PREFIX:-}" ]]; then
  for lvrs_candidate in \
    "$HOME/.local/LVRS" \
    "$HOME/.local/lvrs" \
    "$HOME/Developer/LVRS/build-install" \
    "$HOME/Developer/LVRS/install"; do
    if [[ -d "$lvrs_candidate/include/LVRS" || -d "$lvrs_candidate/lib/cmake" || -d "$lvrs_candidate/lib/qt6/qml" ]]; then
      export LVRS_PREFIX="$lvrs_candidate"
      break
    fi
  done
fi

if [[ -n "${LVRS_PREFIX:-}" && -d "$LVRS_PREFIX" ]]; then
  _pathvar_prepend_unique CMAKE_PREFIX_PATH "$LVRS_PREFIX"
  _pathvar_prepend_unique CMAKE_INCLUDE_PATH "$LVRS_PREFIX/include"
  _pathvar_prepend_unique CMAKE_LIBRARY_PATH "$LVRS_PREFIX/lib"
  _pathvar_prepend_unique CPATH "$LVRS_PREFIX/include"
  _pathvar_prepend_unique LIBRARY_PATH "$LVRS_PREFIX/lib"
  _pathvar_prepend_unique DYLD_LIBRARY_PATH "$LVRS_PREFIX/lib"
  _pathvar_prepend_unique DYLD_FRAMEWORK_PATH "$LVRS_PREFIX/lib"
  _pathvar_prepend_unique QML2_IMPORT_PATH "$LVRS_PREFIX/lib/qt6/qml"
  _pathvar_prepend_unique QT_QML_IMPORT_PATH "$LVRS_PREFIX/lib/qt6/qml"
  _pathvar_prepend_unique QT_PLUGIN_PATH "$LVRS_PREFIX/lib/qt6/plugins"
fi

unset -f _pathvar_prepend_unique
unset base_path brew_prefix_candidate jdk_candidate qt_fallback lvrs_candidate
. "$HOME/.cargo/env"
