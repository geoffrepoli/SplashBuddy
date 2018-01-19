#!/usr/bin/env bash

loggedInUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

APP_PATH="/Library/Application Support/SplashBuddy/SplashBuddy.app"
DONE_FILE="/var/db/.SplashBuddyDone"

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

  launchctl asuser $(id -u $loggedInUser) open -a "$APP_PATH"

elif [ -f "$DONE_FILE" ]; then

  launchctl bootout system/io.fti.SplashBuddy.launch
  rm -rf /Library/Application\ Support/SplashBuddy
  rm -f /Library/LaunchDaemons/io.fti.SplashBuddy.launch.plist
  rm -f /Library/Preferences/io.fti.SplashBuddy.plist
  rm -f "$DONE_FILE"

fi

exit 0
