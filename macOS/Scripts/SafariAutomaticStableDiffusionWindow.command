#!/bin/zsh

sudo -u $(logname) osascript -e 'tell application "Safari"
    activate
    make new document
    set URL of front document to "http://192.168.50.140:7860/"
    tell front window
    make new tab at end
    set URL of (last tab) to "https://youtube.com"
    end tell
end tell'
