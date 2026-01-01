
eval "$(/opt/homebrew/bin/brew shellenv)"
echo eval "$(/opt/homebrew/bin/brew shellenv)" eval export HOMEBREW_PREFIX="/opt/homebrew";
export HOMEBREW_CELLAR="/opt/homebrew/Cellar";
export HOMEBREW_REPOSITORY="/opt/homebrew";
PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/Users/ymy/.rbenv/shims:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/Library/Apple/usr/bin:/Library/TeX/texbin:/Applications/Wireshark.app/Contents/MacOS:/Applications/Little Snitch.app/Contents/Components:/Applications/iTerm.app/Contents/Resources/utilities"; export PATH;
[ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}";
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}";

#KDE
export KDEDIRS=$KDEDIRS:$HOME/Library/Preferences/KDE:/usr/local/kde4
export PATH=/usr/local/kde4/bin:$PATH
export DYLD_LIBRARY_PATH=/usr/local/kde4/lib:$DYLD_LIBRARY_PATH
launchctl setenv DYLD_LIBRARY_PATH /usr/local/kde4/lib:$DYLD_LIBRARY_PATH
export XDG_DATA_HOME=$HOME/Library/Preferences/KDE/share
export XDG_DATA_DIRS=/usr/local/kde4/share:/usr/local/share:/usr/share

##
# Your previous /Users/ymy/.zprofile file was backed up as /Users/ymy/.zprofile.macports-saved_2025-04-28_at_11:01:47
##

# MacPorts Installer addition on 2025-04-28_at_11:01:47: adding an appropriate PATH variable for use with MacPorts.
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.eval "$(/opt/homebrew/bin/brew shellenv)"
