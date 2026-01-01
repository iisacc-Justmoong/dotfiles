# launchctl load ~/Library/LaunchAgents/com.user..plist
# launchctl start com.user.

cp -fv ~/.dotfiles/Scripts/launchd/*.plist ~/Library/LaunchAgents

launchctl load ~/Library/LaunchAgents/com.user.SafariAutomaticStableDiffusionWindow.plist
launchctl load ~/Library/LaunchAgents/com.user.LaunchTasks.plist
launchctl load ~/Library/LaunchAgents/com.user.LaunchMusicPlay.plist

launchctl start com.user.SafariAutomaticStableDiffusionWindow
launchctl start com.user.LaunchTasks
launchctl start com.user.LaunchMusicPlay

ls -l ~/Library/LaunchAgents
