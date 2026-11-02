#!/bin/zsh
# Builds Perch and installs it to ~/Applications/Perch.app.
# Build products live in ~/Library/Developer/Perch, outside the repo
# (and outside Dropbox or iCloud, which would try to sync them).
#
# Usage: ./build.sh            release build, install
#        ./build.sh --debug    debug build, install
#        ./build.sh --open     install, then quit the running copy and open the new one
#
# Environment:
#   APP_DIR=<dir>        put Perch.app there instead of ~/Applications (tools/release.sh uses dist/)
#   VERSION=1.2.0        CFBundleShortVersionString. Default: the latest v* tag, or 0.1.0
#   BUILD=202611011200   CFBundleVersion, which Sparkle compares. Default: the current time
#   SIGN_IDENTITY=...    signing identity. A "Developer ID Application" identity also turns on
#                        the hardened runtime and a secure timestamp, which notarization needs
set -euo pipefail
here=${0:A:h}
name="Perch"
scratch="$HOME/Library/Developer/$name/build"
config=release
[[ " $* " == *" --debug "* ]] && config=debug

# Sign with your Apple Development certificate when you have one (Xcode >
# Settings > Accounts). Otherwise sign ad hoc, which is fine for your own Mac.
identity="${SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)
fi
[[ -n "$identity" ]] || identity=-
sign_flags=(--force --sign "$identity")
[[ "$identity" == "Developer ID Application"* ]] && sign_flags+=(--options runtime --timestamp)

version="${VERSION:-$(git -C "$here" describe --tags --abbrev=0 --match 'v*' 2>/dev/null | sed 's/^v//' || true)}"
[[ -n "$version" ]] || version="0.1.0"
build="${BUILD:-$(date +%Y%m%d%H%M)}"

# SwiftData macros, actool, and ictool come with Xcode, not the Command Line Tools.
xcrun --find actool >/dev/null 2>&1 || { echo "Select Xcode first: sudo xcode-select -s /Applications/Xcode.app"; exit 1; }
swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error|warning|Build complete" | grep -v "^\[" || true
bin="$scratch/$config/$name"
[[ -x "$bin" ]] || { echo "build failed"; exit 1; }
# swift build can report success while an edited file failed to compile. Catch that.
stale=$(find "$here/Sources" -name '*.swift' -newer "$bin" | head -1)
if [[ -n "$stale" ]]; then
  echo "build failed: binary is older than $stale"
  swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error" | head -20
  exit 1
fi

app_dir="${APP_DIR:-$HOME/Applications}"
app="$app_dir/$name.app"
mkdir -p "$app_dir"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$bin" "$app/Contents/MacOS/$name"
sed -e "s/__BUILD__/$build/" -e "s/__VERSION__/$version/" "$here/Info.plist.in" > "$app/Contents/Info.plist"
# The icon: Icon/AppIcon.icon -> Resources/Assets.car + AppIcon.icns, rebuilt when it changed.
if [[ -d "$here/Icon/AppIcon.icon" ]]; then
  car="$here/Resources/Assets.car"
  if [[ ! -f "$car" || -n "$(find "$here/Icon/AppIcon.icon" -newer "$car" | head -1)" ]]; then
    "$here/tools/make_icon.sh"
  fi
  cp -X "$car" "$here/Resources/AppIcon.icns" "$app/Contents/Resources/"
fi

# Sparkle ships as a framework. SwiftPM links it but does not bundle it.
sparkle="$scratch/$config/Sparkle.framework"
[[ -d "$sparkle" ]] || sparkle="$scratch/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$sparkle" "$app/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/$name" 2>/dev/null || true

xattr -cr "$app"
# Sign from the inside out, as Sparkle's documentation describes. No --deep.
fw="$app/Contents/Frameworks/Sparkle.framework"
quiet() { "$@" 2>&1 | grep -v "replacing existing signature" || true; }
quiet codesign "${sign_flags[@]}" "$fw/Versions/B/XPCServices/Installer.xpc"
quiet codesign "${sign_flags[@]}" --preserve-metadata=entitlements "$fw/Versions/B/XPCServices/Downloader.xpc"
quiet codesign "${sign_flags[@]}" "$fw/Versions/B/Autoupdate"
quiet codesign "${sign_flags[@]}" "$fw/Versions/B/Updater.app"
quiet codesign "${sign_flags[@]}" "$fw"
quiet codesign "${sign_flags[@]}" "$app"
codesign --verify --strict "$app" || { echo "signature check failed"; exit 1; }
echo "installed $app $version ($build) (signed: ${identity})"
# The CLI: the app binary under a short name on PATH (bama agent-cli skill).
mkdir -p "$HOME/.local/bin"
ln -sf "$app/Contents/MacOS/$name" "$HOME/.local/bin/perch"

if [[ " $* " == *" --open "* ]]; then
  osascript -e "quit app \"$name\"" 2>/dev/null || true
  sleep 0.5
  open "$app"
fi
