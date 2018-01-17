#!/usr/bin/env bash

loggedInUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
loggedInUserID=$(id -u $loggedInUser)

APP_PATH="/Library/Application Support/SplashBuddy/SplashBuddy.app"
DONE_FILE="/var/db/.SplashBuddyDone"

function getAssetNum() {
  assetNum=$(launchctl asuser $loggedInUserID osascript -e 'display dialog "Enter Asset Tag #:" default answer "" giving up after 86400 with text buttons {"OK"} default button 1' -e 'return text returned of result')
  until $assetNum; do
  assetNum=$(launchctl asuser $loggedInUserID osascript -e 'display dialog "Invalid Asset Tag. Try again:" default answer "" giving up after 86400 with text buttons {"OK"} default button 1' -e 'return text returned of result')
  done
  confirm=$(launchctl asuser $loggedInUserID osascript -e 'display dialog "Confirm Asset Tag #:" default answer "" giving up after 86400 with text buttons {"Confirm"} default button 1' -e 'return text returned of result')
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

  # Rename machine to provided asset number
  getAssetNum
  until [ "$confirm" = "$assetNum" ]
  do getAssetNum
  done

  scutil --set ComputerName "$assetNum"
  scutil --set LocalHostName "$assetNum"
  scutil --set LocalHostName ''

  # Bind using jamf policy
  ( /usr/local/bin/jamf policy -trigger bind ) & PID=$!

  # Launch SplashBuddy.app as console user
  launchctl asuser $loggedInUserID open -a "$APP_PATH"

  # Wait until domain binding policy completes
  while kill -0 $PID &> /dev/null
  do sleep 0.1
  done

  # Trigger the SplashBuddy install workflow
  /usr/local/bin/jamf policy -trigger SBLaunch

elif [ -f "$DONE_FILE" ]; then

  launchctl bootout system/io.fti.SplashBuddy.launch
  rm -rf /Library/Application\ Support/SplashBuddy
  rm -f /Library/LaunchDaemons/io.fti.SplashBuddy.launch.plist
  rm -f /Library/Preferences/io.fti.SplashBuddy.plist
  rm -f "$DONE_FILE"

fi

exit 0
