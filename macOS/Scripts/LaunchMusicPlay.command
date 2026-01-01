#!/bin/zsh

osascript -e 'tell application "Music"
	activate
	
	set shuffle enabled to true

	set song repeat to all
	
	if exists (playlist "Select Game") then
		play playlist "Select Game"
	else
		return
	end if
	
end tell'