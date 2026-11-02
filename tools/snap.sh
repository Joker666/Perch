#!/bin/zsh
# Snapshots of every page in light and dark, with seed data, on a fresh test store.
# Usage: tools/snap.sh            all pages
#        APP_SNAPSHOT_PAGES=starred,settings tools/snap.sh   only those pages
#        tools/snap.sh -AppleShowScrollBars Always          extra arguments go to the app
set -u
app=~/Applications/Perch.app/Contents/MacOS/Perch
store=/tmp/Perch-test.store
shots=/tmp/Perch-shots
# A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
rm -rf ~/Library/Saved\ Application\ State/com.rafi.perch.savedState
# Seed data only fills an empty store, so start from nothing.
rm -f $store $store-shm $store-wal
rm -rf $shots
APP_STORE=$store APP_SEED=1 APP_SNAPSHOT=$shots $app "$@"
