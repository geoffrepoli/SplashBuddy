#!/usr/bin/env bash

loggedInUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
loggedInUserHome=$(dscl . read /Users/$loggedInUser NFSHomeDirectory | cut -d' ' -f2-)

touch "$loggedInUserHome/Library/.SplashBuddyDone"
