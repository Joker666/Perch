#!/bin/zsh
# Makes iOS/Icons.xcassets: the iOS app's alternate icons, drawn by the Mac app's
# AppIconView. Run it after a change to the icon drawing or the themes.
set -euo pipefail
here=${0:A:h:h}
rm -rf "$here/iOS/Icons.xcassets"
/Applications/Perch.app/Contents/MacOS/Perch --ios-icons "$here/iOS/Icons.xcassets"
