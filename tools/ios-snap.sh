#!/bin/zsh
# Screenshots of the iOS app in the simulator with sample todos, one per page
# and theme, in /tmp/Perch-ios-shots/<page>-<theme>.png. Build the app first:
#   cd iOS && xcodegen && xcodebuild -scheme PerchPhone -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath ~/Library/Developer/Perch/ios-build build
#   tools/ios-snap.sh                     every page in Midnight and Matcha
#   PAGES="list edit" THEMES=pool tools/ios-snap.sh
# A page ending in -empty runs without sample todos, like archive-empty.
set -euo pipefail
device="${DEVICE:-iPhone 18 Pro}"
app="$HOME/Library/Developer/Perch/ios-build/Build/Products/Debug-iphonesimulator/Perch.app"
out=/tmp/Perch-ios-shots
mkdir -p "$out"
xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl install "$device" "$app"
for theme in ${=THEMES:-midnight matcha}; do
  for page in ${=PAGES:-list edit archive archive-empty settings}; do
    store="/tmp/Perch-ios-$page-$theme.store"
    rm -f "$store" "$store-shm" "$store-wal"
    xcrun simctl terminate "$device" com.rafi.perch 2>/dev/null || true
    seed=1; [[ "$page" == *-empty ]] && seed=0
    SIMCTL_CHILD_APP_STORE="$store" SIMCTL_CHILD_APP_SEED=$seed SIMCTL_CHILD_APP_PAGE="${page%-empty}" SIMCTL_CHILD_APP_THEME="$theme" \
      xcrun simctl launch "$device" com.rafi.perch >/dev/null
    sleep 2.5
    xcrun simctl io "$device" screenshot "$out/$page-$theme.png" >/dev/null 2>&1
    rm -f "$store" "$store-shm" "$store-wal"
  done
done
xcrun simctl terminate "$device" com.rafi.perch 2>/dev/null || true
echo "wrote $out"
