#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
STATE_DIR="${STATE_DIR:-$DOTFILES_DIR/machine-state}"
PLIST_DIR="$STATE_DIR/plists"
DEFAULTS_DIR="$STATE_DIR/defaults"
RUNTIME_DIR="$STATE_DIR/runtime"
PREFERENCES_DIR="$STATE_DIR/preferences"
LAUNCHD_DIR="$STATE_DIR/launchd"
PACKAGES_DIR="$STATE_DIR/packages"
SYSTEM_DIR="$STATE_DIR/system"
METADATA_FILE="$STATE_DIR/metadata.env"
SUMMARY_FILE="$STATE_DIR/backup-summary.txt"
DEFAULTS_WRITE_SCRIPT="$DEFAULTS_DIR/apply-defaults-write.sh"
DEFAULTS_DOMAIN_LIST="$DEFAULTS_DIR/domains.list"
DEFAULTS_DOMAIN_INDEX="$DEFAULTS_DIR/domains.index.tsv"
BREWFILE_PATH="$DOTFILES_DIR/Brewfile"
BACKUP_DATE="$(date '+%Y-%m-%d')"
BACKUP_TS="$(date '+%Y-%m-%d %H:%M:%S')"
USER_UID="$(id -u)"

mkdir -p "$PLIST_DIR" "$DEFAULTS_DIR" "$RUNTIME_DIR" "$PREFERENCES_DIR" "$LAUNCHD_DIR" "$PACKAGES_DIR" "$SYSTEM_DIR"

backup_plist() {
  local src="$1"
  local dst="$2"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$dst"
  fi
}

trim_value() {
  printf "%s" "$1" | awk '{$1=$1; print}'
}

normalize_bool() {
  local raw="$1"
  case "$raw" in
    1|true|TRUE|yes|YES) printf "true" ;;
    0|false|FALSE|no|NO) printf "false" ;;
    *) return 1 ;;
  esac
}

sanitize_filename() {
  local raw="$1"
  local sanitized
  sanitized="$(printf "%s" "$raw" | tr '[:space:]/:' '___' | sed -E 's/[^A-Za-z0-9._-]/_/g')"
  sanitized="${sanitized#_}"
  sanitized="${sanitized%_}"
  if [[ -z "$sanitized" ]]; then
    sanitized="domain"
  fi
  printf "%s" "$sanitized"
}

short_hash() {
  local raw="$1"
  if command -v shasum >/dev/null 2>&1; then
    printf "%s" "$raw" | shasum | awk '{print substr($1,1,10)}'
    return 0
  fi

  if command -v md5 >/dev/null 2>&1; then
    printf "%s" "$raw" | md5 | awk '{print substr($NF,1,10)}'
    return 0
  fi

  printf "%s" "$raw" | cksum | awk '{print $1}'
}

capture_command() {
  local output_file="$1"
  shift
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf "[missing command] %s\n" "$command_name" >"$output_file"
    return 0
  fi

  if "$@" >"$output_file" 2>&1; then
    return 0
  fi

  local exit_code=$?
  printf '\n[exit code] %s\n' "$exit_code" >>"$output_file"
  return 0
}

capture_shell() {
  local output_file="$1"
  local command_line="$2"

  if /bin/bash -lc "$command_line" >"$output_file" 2>&1; then
    return 0
  fi

  local exit_code=$?
  printf '\n[exit code] %s\n' "$exit_code" >>"$output_file"
  return 0
}

copy_tree_if_exists() {
  local src_dir="$1"
  local dst_dir="$2"

  mkdir -p "$dst_dir"
  if [[ ! -d "$src_dir" ]]; then
    return 0
  fi

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src_dir"/ "$dst_dir"/ >/dev/null 2>&1 || true
    return 0
  fi

  find "$dst_dir" -mindepth 1 -delete 2>/dev/null || true
  cp -R "$src_dir"/. "$dst_dir"/ 2>/dev/null || true
}

backup_preferences_plists() {
  local src_preferences="$HOME/Library/Preferences"
  local dst_user="$PREFERENCES_DIR/user"
  local dst_byhost="$PREFERENCES_DIR/byhost"

  mkdir -p "$dst_user" "$dst_byhost"
  find "$dst_user" -maxdepth 1 -type f -name "*.plist" -delete 2>/dev/null || true
  find "$dst_byhost" -maxdepth 1 -type f -name "*.plist" -delete 2>/dev/null || true

  if [[ ! -d "$src_preferences" ]]; then
    return 0
  fi

  while IFS= read -r -d '' plist_path; do
    cp -f "$plist_path" "$dst_user/" 2>/dev/null || true
  done < <(find "$src_preferences" -maxdepth 1 -type f -name "*.plist" -print0)

  if [[ -d "$src_preferences/ByHost" ]]; then
    while IFS= read -r -d '' plist_path; do
      cp -f "$plist_path" "$dst_byhost/" 2>/dev/null || true
    done < <(find "$src_preferences/ByHost" -maxdepth 1 -type f -name "*.plist" -print0)
  fi
}

collect_defaults_domains() {
  local tmp_domains
  tmp_domains="$(mktemp)"

  local -a static_domains
  static_domains=(
    "NSGlobalDomain"
    "com.apple.ActivityMonitor"
    "com.apple.DiskUtility"
    "com.apple.HIToolbox"
    "com.apple.LaunchServices"
    "com.apple.NetworkBrowser"
    "com.apple.QuickTimePlayerX"
    "com.apple.Safari"
    "com.apple.SoftwareUpdate"
    "com.apple.Terminal"
    "com.apple.TextEdit"
    "com.apple.WindowManager"
    "com.apple.appstore"
    "com.apple.commerce"
    "com.apple.controlcenter"
    "com.apple.desktopservices"
    "com.apple.dock"
    "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    "com.apple.finder"
    "com.apple.loginwindow"
    "com.apple.screencapture"
    "com.apple.spaces"
    "com.apple.symbolichotkeys"
    "com.apple.trackpad"
    "com.apple.universalaccess"
  )

  local domain
  for domain in "${static_domains[@]}"; do
    printf "%s\n" "$domain" >>"$tmp_domains"
  done

  while IFS= read -r domain; do
    domain="$(trim_value "$domain")"
    [[ -z "$domain" ]] && continue
    printf "%s\n" "$domain" >>"$tmp_domains"
  done < <(defaults domains 2>/dev/null | tr ',' '\n')

  if [[ -d "$HOME/Library/Preferences" ]]; then
    while IFS= read -r -d '' plist_path; do
      domain="$(basename "$plist_path" .plist)"
      domain="$(trim_value "$domain")"
      [[ -z "$domain" ]] && continue
      printf "%s\n" "$domain" >>"$tmp_domains"
    done < <(find "$HOME/Library/Preferences" -maxdepth 1 -type f -name "*.plist" -print0)
  fi

  if [[ -d "$HOME/Library/Preferences/ByHost" ]]; then
    while IFS= read -r -d '' plist_path; do
      domain="$(basename "$plist_path" .plist)"
      domain="$(trim_value "$domain")"
      [[ -z "$domain" ]] && continue
      printf "%s\n" "$domain" >>"$tmp_domains"
    done < <(find "$HOME/Library/Preferences/ByHost" -maxdepth 1 -type f -name "*.plist" -print0)
  fi

  sort -u "$tmp_domains" >"$DEFAULTS_DOMAIN_LIST"
  rm -f "$tmp_domains"
}

export_defaults_domains() {
  find "$DEFAULTS_DIR" -maxdepth 1 -type f \( -name "*.read.txt" -o -name "*.export.plist" \) -delete 2>/dev/null || true
  : >"$DEFAULTS_DOMAIN_INDEX"

  local domain file_base
  while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    file_base="$(sanitize_filename "$domain").$(short_hash "$domain")"
    printf "%s\t%s\n" "$domain" "$file_base" >>"$DEFAULTS_DOMAIN_INDEX"
    defaults read "$domain" >"$DEFAULTS_DIR/$file_base.read.txt" 2>/dev/null || true
    defaults export "$domain" "$DEFAULTS_DIR/$file_base.export.plist" >/dev/null 2>&1 || true
  done <"$DEFAULTS_DOMAIN_LIST"
}

generate_defaults_apply_script() {
  cat >"$DEFAULTS_WRITE_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

# Generated by Scripts/machine-state-backup.sh at $BACKUP_TS
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
DOMAIN_INDEX_FILE="\$SCRIPT_DIR/domains.index.tsv"

if [[ -f "\$DOMAIN_INDEX_FILE" ]]; then
  while IFS=\$'\t' read -r domain file_base; do
    [[ -n "\$domain" && -n "\$file_base" ]] || continue
    export_file="\$SCRIPT_DIR/\${file_base}.export.plist"
    if [[ -f "\$export_file" ]]; then
      defaults import "\$domain" "\$export_file" >/dev/null 2>&1 || true
    fi
  done <"\$DOMAIN_INDEX_FILE"
fi
EOF

  local -a key_specs
  key_specs=(
    "com.apple.dock|springboard-rows|int"
    "com.apple.dock|springboard-columns|int"
    "com.apple.universalaccess|reduceTransparency|bool"
    "com.apple.dock|tilesize|int"
    "com.apple.LaunchServices|LSQuarantine|bool"
    "NSGlobalDomain|AppleFontSmoothing|int"
    "com.apple.dock|mouse-over-hilite-stack|bool"
    "com.apple.dock|expose-animation-duration|float"
    "com.apple.dock|expose-group-by-app|bool"
    "com.apple.dock|mru-spaces|bool"
    "com.apple.finder|AppleShowAllFiles|bool"
    "NSGlobalDomain|AppleShowAllExtensions|bool"
    "com.apple.finder|ShowStatusBar|bool"
    "com.apple.finder|ShowPathbar|bool"
    "com.apple.finder|_FXShowPosixPathInTitle|bool"
    "com.apple.finder|FXEnableExtensionChangeWarning|bool"
    "NSGlobalDomain|com.apple.springing.enabled|bool"
    "NSGlobalDomain|com.apple.springing.delay|float"
    "com.apple.desktopservices|DSDontWriteNetworkStores|bool"
    "com.apple.desktopservices|DSDontWriteUSBStores|bool"
    "com.apple.finder|WarnOnEmptyTrash|bool"
    "com.apple.NetworkBrowser|BrowseAllInterfaces|bool"
    "com.apple.Safari|AutoOpenSafeDownloads|bool"
    "com.apple.Safari|ShowFavoritesBar|bool"
    "com.apple.Safari|ShowSidebarInTopSites|bool"
    "com.apple.Safari|DebugSnapshotsUpdatePolicy|int"
    "com.apple.Safari|IncludeInternalDebugMenu|bool"
    "com.apple.Safari|IncludeDevelopMenu|bool"
    "com.apple.Safari|WebKitDeveloperExtrasEnabledPreferenceKey|bool"
    "com.apple.Safari|com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled|bool"
    "NSGlobalDomain|WebKitDeveloperExtras|bool"
    "com.apple.Safari|WebAutomaticSpellingCorrectionEnabled|bool"
    "com.apple.Safari|AutoFillFromAddressBook|bool"
    "com.apple.Safari|AutoFillPasswords|bool"
    "com.apple.Safari|AutoFillCreditCardData|bool"
    "com.apple.Safari|AutoFillMiscellaneousForms|bool"
    "com.apple.Safari|SendDoNotTrackHTTPHeader|bool"
    "com.apple.Safari|InstallExtensionUpdatesAutomatically|bool"
    "com.apple.Safari|WebKitJavaScriptCanOpenWindowsAutomatically|bool"
    "com.apple.Safari|com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically|bool"
    "com.apple.appstore|WebKitDeveloperExtras|bool"
    "com.apple.appstore|ShowDebugMenu|bool"
    "com.apple.SoftwareUpdate|AutomaticCheckEnabled|bool"
    "com.apple.SoftwareUpdate|ScheduleFrequency|int"
    "com.apple.SoftwareUpdate|AutomaticDownload|int"
    "com.apple.SoftwareUpdate|CriticalUpdateInstall|int"
    "com.apple.SoftwareUpdate|ConfigDataInstall|int"
    "com.apple.commerce|AutoUpdate|bool"
    "com.apple.commerce|AutoUpdateRestartRequired|bool"
    "com.apple.DiskUtility|DUDebugMenuEnabled|bool"
    "com.apple.DiskUtility|advanced-image-options|bool"
    "com.apple.QuickTimePlayerX|MGPlayMovieOnOpen|bool"
  )

  local spec domain key value_type raw_value first_line trimmed_value
  for spec in "${key_specs[@]}"; do
    IFS="|" read -r domain key value_type <<<"$spec"

    if ! raw_value="$(defaults read "$domain" "$key" 2>/dev/null)"; then
      printf "# skipped: defaults read %s %s\n" "$domain" "$key" >>"$DEFAULTS_WRITE_SCRIPT"
      continue
    fi

    first_line="$(printf "%s\n" "$raw_value" | head -n 1)"
    trimmed_value="$(trim_value "$first_line")"

    case "$value_type" in
      bool)
        if bool_value="$(normalize_bool "$trimmed_value")"; then
          printf "defaults write %q %q -bool %s\n" "$domain" "$key" "$bool_value" >>"$DEFAULTS_WRITE_SCRIPT"
        else
          printf "# skipped invalid bool: %s %s=%q\n" "$domain" "$key" "$trimmed_value" >>"$DEFAULTS_WRITE_SCRIPT"
        fi
        ;;
      int)
        if [[ "$trimmed_value" =~ ^-?[0-9]+$ ]]; then
          printf "defaults write %q %q -int %s\n" "$domain" "$key" "$trimmed_value" >>"$DEFAULTS_WRITE_SCRIPT"
        else
          printf "# skipped invalid int: %s %s=%q\n" "$domain" "$key" "$trimmed_value" >>"$DEFAULTS_WRITE_SCRIPT"
        fi
        ;;
      float)
        if [[ "$trimmed_value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
          printf "defaults write %q %q -float %s\n" "$domain" "$key" "$trimmed_value" >>"$DEFAULTS_WRITE_SCRIPT"
        else
          printf "# skipped invalid float: %s %s=%q\n" "$domain" "$key" "$trimmed_value" >>"$DEFAULTS_WRITE_SCRIPT"
        fi
        ;;
      string)
        printf "defaults write %q %q -string %q\n" "$domain" "$key" "$first_line" >>"$DEFAULTS_WRITE_SCRIPT"
        ;;
    esac
  done

  {
    echo
    echo "killall cfprefsd >/dev/null 2>&1 || true"
    echo "killall Dock >/dev/null 2>&1 || true"
    echo "killall Finder >/dev/null 2>&1 || true"
  } >>"$DEFAULTS_WRITE_SCRIPT"

  chmod +x "$DEFAULTS_WRITE_SCRIPT"
}

backup_launchd_state() {
  copy_tree_if_exists "$HOME/Library/LaunchAgents" "$LAUNCHD_DIR/user-LaunchAgents"
  copy_tree_if_exists "/Library/LaunchAgents" "$LAUNCHD_DIR/system-LaunchAgents"
  copy_tree_if_exists "/Library/LaunchDaemons" "$LAUNCHD_DIR/system-LaunchDaemons"

  capture_command "$LAUNCHD_DIR/launchctl.list.txt" launchctl list
  capture_shell "$LAUNCHD_DIR/launchctl.print-disabled.user.txt" "launchctl print-disabled gui/$USER_UID"
  capture_shell "$LAUNCHD_DIR/launchctl.print-disabled.system.txt" "launchctl print-disabled system"
}

capture_package_state() {
  capture_command "$PACKAGES_DIR/brew.formula.versions.txt" brew list --formula --versions
  capture_command "$PACKAGES_DIR/brew.cask.versions.txt" brew list --cask --versions
  capture_command "$PACKAGES_DIR/brew.taps.txt" brew tap
  capture_command "$PACKAGES_DIR/brew.doctor.txt" brew doctor
  capture_command "$PACKAGES_DIR/mas.list.txt" mas list
  capture_command "$PACKAGES_DIR/npm.global.txt" npm list -g --depth=0
  capture_command "$PACKAGES_DIR/pip3.freeze.txt" pip3 freeze
  capture_command "$PACKAGES_DIR/pipx.list.txt" pipx list
  capture_command "$PACKAGES_DIR/gem.list.txt" gem list
  capture_command "$PACKAGES_DIR/cargo.install.txt" cargo install --list
}

capture_system_state() {
  capture_command "$SYSTEM_DIR/sw_vers.txt" sw_vers
  capture_command "$SYSTEM_DIR/uname.txt" uname -a
  capture_command "$SYSTEM_DIR/scutil.computername.txt" scutil --get ComputerName
  capture_command "$SYSTEM_DIR/scutil.localhostname.txt" scutil --get LocalHostName
  capture_command "$SYSTEM_DIR/scutil.hostname.txt" scutil --get HostName
  capture_command "$SYSTEM_DIR/networksetup.services.txt" networksetup -listallnetworkservices
  capture_command "$SYSTEM_DIR/pmset.g.txt" pmset -g
  capture_command "$SYSTEM_DIR/fdesetup.status.txt" fdesetup status
  capture_command "$SYSTEM_DIR/crontab.txt" crontab -l
  capture_command "$SYSTEM_DIR/login-items.txt" osascript -e 'tell application "System Events" to get the name of every login item'
  capture_shell "$SYSTEM_DIR/system_profiler.hw_sw.txt" "system_profiler SPHardwareDataType SPSoftwareDataType"
  capture_shell "$SYSTEM_DIR/applications.system.txt" "find /Applications -maxdepth 2 -type d -name '*.app' | sort"
  capture_shell "$SYSTEM_DIR/applications.user.txt" "find \"$HOME/Applications\" -maxdepth 2 -type d -name '*.app' | sort"
  capture_shell "$SYSTEM_DIR/environment.txt" "env | sort"
}

write_summary() {
  local defaults_domain_count defaults_export_count
  local preferences_user_count preferences_byhost_count
  local user_launchagents_count system_launchagents_count system_launchdaemons_count

  defaults_domain_count="$(wc -l <"$DEFAULTS_DOMAIN_LIST" | tr -d ' ')"
  defaults_export_count="$(find "$DEFAULTS_DIR" -maxdepth 1 -type f -name "*.export.plist" | wc -l | tr -d ' ')"
  preferences_user_count="$(find "$PREFERENCES_DIR/user" -maxdepth 1 -type f -name "*.plist" | wc -l | tr -d ' ')"
  preferences_byhost_count="$(find "$PREFERENCES_DIR/byhost" -maxdepth 1 -type f -name "*.plist" | wc -l | tr -d ' ')"
  user_launchagents_count="$(find "$LAUNCHD_DIR/user-LaunchAgents" -maxdepth 1 -type f -name "*.plist" 2>/dev/null | wc -l | tr -d ' ')"
  system_launchagents_count="$(find "$LAUNCHD_DIR/system-LaunchAgents" -maxdepth 1 -type f -name "*.plist" 2>/dev/null | wc -l | tr -d ' ')"
  system_launchdaemons_count="$(find "$LAUNCHD_DIR/system-LaunchDaemons" -maxdepth 1 -type f -name "*.plist" 2>/dev/null | wc -l | tr -d ' ')"

  cat >"$SUMMARY_FILE" <<EOF
BACKUP_TS=$BACKUP_TS
DEFAULTS_DOMAIN_COUNT=$defaults_domain_count
DEFAULTS_EXPORT_COUNT=$defaults_export_count
PREFERENCES_USER_PLIST_COUNT=$preferences_user_count
PREFERENCES_BYHOST_PLIST_COUNT=$preferences_byhost_count
LAUNCHAGENTS_USER_COUNT=$user_launchagents_count
LAUNCHAGENTS_SYSTEM_COUNT=$system_launchagents_count
LAUNCHDAEMONS_SYSTEM_COUNT=$system_launchdaemons_count
EOF
}

write_metadata() {
  local backup_user backup_group os_version os_build machine_arch
  local computer_name local_host_name host_name

  backup_user="$(id -un 2>/dev/null || echo unknown)"
  backup_group="$(id -gn 2>/dev/null || echo unknown)"
  os_version="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
  os_build="$(sw_vers -buildVersion 2>/dev/null || echo unknown)"
  machine_arch="$(uname -m 2>/dev/null || echo unknown)"
  computer_name="$(scutil --get ComputerName 2>/dev/null || echo unknown)"
  local_host_name="$(scutil --get LocalHostName 2>/dev/null || echo unknown)"
  host_name="$(scutil --get HostName 2>/dev/null || echo unknown)"

  {
    printf 'BACKUP_DATE=%q\n' "$BACKUP_DATE"
    printf 'BACKUP_TS=%q\n' "$BACKUP_TS"
    printf 'DOTFILES_DIR=%q\n' "$DOTFILES_DIR"
    printf 'BACKUP_USER=%q\n' "$backup_user"
    printf 'BACKUP_GROUP=%q\n' "$backup_group"
    printf 'BACKUP_UID=%q\n' "$USER_UID"
    printf 'OS_VERSION=%q\n' "$os_version"
    printf 'OS_BUILD=%q\n' "$os_build"
    printf 'MACHINE_ARCH=%q\n' "$machine_arch"
    printf 'COMPUTER_NAME=%q\n' "$computer_name"
    printf 'LOCAL_HOST_NAME=%q\n' "$local_host_name"
    printf 'HOST_NAME=%q\n' "$host_name"
  } >"$METADATA_FILE"
}

if [[ -x "$DOTFILES_DIR/Scripts/machine-clean-generated.sh" ]]; then
  "$DOTFILES_DIR/Scripts/machine-clean-generated.sh" >/dev/null 2>&1 || true
fi

backup_plist "$HOME/Library/Preferences/com.apple.dock.plist" "$PLIST_DIR/com.apple.dock.snapshot.plist"
backup_plist "$HOME/Library/Preferences/com.apple.finder.plist" "$PLIST_DIR/com.apple.finder.snapshot.plist"
defaults export com.apple.dock "$PLIST_DIR/com.apple.dock.export.plist" >/dev/null 2>&1 || true
defaults export com.apple.finder "$PLIST_DIR/com.apple.finder.export.plist" >/dev/null 2>&1 || true

if command -v brew >/dev/null 2>&1; then
  brew bundle dump --force --file "$BREWFILE_PATH" >/dev/null 2>&1 || true
fi

collect_defaults_domains
export_defaults_domains
generate_defaults_apply_script
backup_preferences_plists
backup_launchd_state
capture_package_state
capture_system_state
write_summary
write_metadata
