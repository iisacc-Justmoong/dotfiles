#!/bin/zsh

# Refresh inherited SDK search paths after checkout and installation relocation.
for sdk_path_variable in PATH CMAKE_PREFIX_PATH CMAKE_INCLUDE_PATH CMAKE_LIBRARY_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH PKG_CONFIG_PATH DYLD_FALLBACK_LIBRARY_PATH DYLD_LIBRARY_PATH DYLD_FRAMEWORK_PATH QML2_IMPORT_PATH QT_QML_IMPORT_PATH QT_PLUGIN_PATH LVRS_PREFIX LVRS_HOST_PREFIX LVRS_PLATFORMS_ROOT LVRS_ROOT; do
  sdk_path_value="${(P)sdk_path_variable}"
  for sdk_package_name in LVRS iiGeneralDocument iiHtmlBlock iiLicenseManager iiLocalDiffusion iiPaintEngine iiSharedCanvas iiUpdateManager iiXml; do
    sdk_old_prefix="$HOME/.local/$sdk_package_name"
    sdk_new_prefix="$HOME/.local/SDK/$sdk_package_name"
    sdk_path_value="${sdk_path_value//$sdk_old_prefix/$sdk_new_prefix}"
  done
  sdk_old_prefix="$HOME/.local/lvrs"
  sdk_new_prefix="$HOME/.local/SDK/LVRS"
  sdk_path_value="${sdk_path_value//$sdk_old_prefix/$sdk_new_prefix}"
  sdk_old_prefix="/Volumes/Storage/Workspace/lib/"
  sdk_new_prefix="/Volumes/Storage/Workspace/SDK/"
  sdk_path_value="${sdk_path_value//$sdk_old_prefix/$sdk_new_prefix}"
  [[ -z "$sdk_path_value" ]] || export "$sdk_path_variable=$sdk_path_value"
done
unset sdk_path_variable sdk_path_value sdk_package_name sdk_old_prefix sdk_new_prefix

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
  "$HOME/.local/SDK/bin" \
  "$HOME/.local/SDK/LVRS/bin" \
  "$HOME/.local/bin" \
  "$HOME/.local/sbin" \
  "$HOME/bin" \
  "$HOME/.cargo/bin" \
  "$HOME/go/bin" \
  "$HOME/.dotnet" \
  "$HOME/.dotnet/tools" \
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

_configure_local_package_prefix() {
  typeset package_prefix="$1"

  [[ -n "$package_prefix" && -d "$package_prefix" ]] || return 0

  _pathvar_prepend_unique PATH "$package_prefix/bin"

  if [[ -d "$package_prefix/include" || -d "$package_prefix/lib" || -d "$package_prefix/lib/cmake" ]]; then
    _pathvar_prepend_unique CMAKE_PREFIX_PATH "$package_prefix"
    _pathvar_prepend_unique CMAKE_INCLUDE_PATH "$package_prefix/include"
    _pathvar_prepend_unique CMAKE_LIBRARY_PATH "$package_prefix/lib"
    _pathvar_prepend_unique CPATH "$package_prefix/include"
    _pathvar_prepend_unique LIBRARY_PATH "$package_prefix/lib"
    _pathvar_prepend_unique DYLD_LIBRARY_PATH "$package_prefix/lib"
  fi
}

for local_package_prefix in \
  "$HOME/.local/SDK/iiGeneralDocument" \
  "$HOME/.local/SDK/iiHtmlBlock" \
  "$HOME/.local/SDK/iiLicenseManager" \
  "$HOME/.local/SDK/iiLocalDiffusion" \
  "$HOME/.local/SDK/iiPaintEngine" \
  "$HOME/.local/SDK/iiSharedCanvas" \
  "$HOME/.local/SDK/iiUpdateManager" \
  "$HOME/.local/SDK/iiXml"; do
  _configure_local_package_prefix "$local_package_prefix"
  _configure_local_package_prefix "$local_package_prefix/platforms/macos"
done

if [[ -z "${LVRS_PREFIX:-}" || ! -d "${LVRS_PREFIX:-}" ]]; then
  for lvrs_candidate in \
    "$HOME/.local/SDK/LVRS/platforms/macos" \
    "$HOME/.local/SDK/LVRS" \
    "$HOME/Developer/LVRS/build-install" \
    "$HOME/Developer/LVRS/install"; do
    if [[ -d "$lvrs_candidate/include/LVRS" || -d "$lvrs_candidate/lib/cmake" || -d "$lvrs_candidate/lib/qt6/qml" ]]; then
      export LVRS_PREFIX="$lvrs_candidate"
      break
    fi
  done
fi

if [[ -n "${LVRS_PREFIX:-}" && -d "$LVRS_PREFIX" ]]; then
  if [[ "$LVRS_PREFIX" == */platforms/* ]]; then
    export LVRS_HOST_PREFIX="${LVRS_HOST_PREFIX:-$LVRS_PREFIX}"
    export LVRS_HOST_PLATFORM="${LVRS_HOST_PLATFORM:-${LVRS_PREFIX##*/}}"
    export LVRS_PLATFORMS_ROOT="${LVRS_PLATFORMS_ROOT:-${LVRS_PREFIX%/*}}"
    export LVRS_ROOT="${LVRS_ROOT:-${LVRS_PLATFORMS_ROOT%/*}}"
    _pathvar_prepend_unique CMAKE_PREFIX_PATH "$LVRS_ROOT"
  fi

  _pathvar_prepend_unique PATH "$LVRS_PREFIX/bin"
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

unset -f _configure_local_package_prefix
unset -f _pathvar_prepend_unique
unset base_path brew_prefix_candidate jdk_candidate qt_fallback local_package_prefix lvrs_candidate
if [[ -r "$HOME/.cargo/env" ]]; then
  . "$HOME/.cargo/env"
fi
export PATH=/usr/local/RemoteDevelopmentToolkit/bin:$PATH
