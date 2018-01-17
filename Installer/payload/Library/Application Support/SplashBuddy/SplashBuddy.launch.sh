#!/bin/bash

loggedInUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
loggedInUserID=$(id -u $loggedInUser)

APP_PATH="/Library/Application Support/SplashBuddy/SplashBuddy.app"
DONE_FILE="/var/db/.SplashBuddyDone"
ICON_FILE="/Library/Application Support/SplashBuddy/jeff-icon.png"
CD_PATH="/Library/Application Support/SplashBuddy/cocoaDialog.app/Contents/MacOS/cocoaDialog"

function getAssetTag() {
	assetTag=$(launchctl asuser $loggedInUserID osascript -e 'set jeffIcon to POSIX file "'"$ICON_FILE"'"' -e 'display dialog "Enter Asset Tag #:" default answer "" giving up after 86400 with icon jeffIcon with text buttons {"OK"} default button 1' -e 'return text returned of result')
	until [[ $assetTag =~ ^[aA][pP][cC][0-9a-dA-D]([0-9]){3}$ ]]; do
	assetTag=$(launchctl asuser $loggedInUserID osascript -e 'set jeffIcon to POSIX file "'"$ICON_FILE"'"' -e 'display dialog "Invalid Asset Tag. Try again:" default answer "" giving up after 86400 with icon jeffIcon with text buttons {"OK"} default button 1' -e 'return text returned of result')
	done
	assetTagVerify=$(launchctl asuser $loggedInUserID osascript -e 'set jeffIcon to POSIX file "'"$ICON_FILE"'"' -e 'display dialog "Confirm Asset Tag #:" default answer "" giving up after 86400 with icon jeffIcon with text buttons {"Confirm"} default button 1' -e 'return text returned of result')
}

function appInstalled {
  codesign --verify "$APP_PATH" && return 0 || return 1
}

function appNotRunning {
  pgrep SplashBuddy && return 1 || return 0
}

function finderRunning {
  pgrep Finder && return 0 || return 1
}

if appNotRunning \
	&& appInstalled \
	&& [ "$loggedInUser" != "_mbsetupuser" ] \
	&& finderRunning \
	&& [ ! -f "$DONE_FILE" ]; then

	sleep 3

	getAssetTag
	until [[ $assetTagVerify = "$assetTag" ]]
	do getAssetTag
	done

	assetTag=$(tr '[:lower:]' '[:upper:]' <<< "$assetTag")

	scutil --set ComputerName "$assetTag"
	scutil --set LocalHostName "$assetTag"

	userDomain=$("$CD_PATH" standard-dropdown \
  	--title "Jefferson IS&T" \
		--text " Select the user's assigned domain:
    " \
		--items "University" "Hospital" \
		--no-newline \
		--no-cancel \
		--float \
		--string-output \
		--icon-file "$ICON_FILE"
	)

	if [[ $userDomain =~ Hospital ]]
	then ( /usr/local/bin/jamf policy -trigger enrollBindTJUH ) & PID=$!
	elif [[ $userDomain =~ University ]]
	then ( /usr/local/bin/jamf policy -trigger enrollBindTJU ) & PID=$!
	fi

  launchctl asuser $loggedInUserID open -a "$APP_PATH"

	while kill -0 $PID &>/dev/null
	do sleep 0.1
	done

	/usr/local/bin/jamf policy -trigger SBLaunch

elif [ -f "$DONE_FILE" ]; then

	launchctl remove -F io.fti.SplashBuddy.launch
	rm -rf /Library/Application\ Support/SplashBuddy
	rm -f /Library/LaunchDaemons/io.fti.SplashBuddy.launch.plist
	rm -f /Library/Preferences/io.fti.SplashBuddy.plist
	rm -f "$DONE_FILE"

fi

exit 0
