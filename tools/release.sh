#!/bin/zsh
# Builds a release: dist/Perch.app, dist/Perch.dmg, and site/appcast.xml.
# The GitHub release workflow runs this. It also works on your Mac.
#
# Usage: VERSION=1.0.0 tools/release.sh
#
# Optional environment (each step is skipped when its values are missing):
#   DEVELOPER_ID          "Developer ID Application: Name (TEAMID)". Without it the app is
#                         signed with your Apple Development identity or ad hoc, and not notarized.
#   APPLE_API_KEY_PATH    App Store Connect API key (.p8) for notarytool
#   APPLE_API_KEY_ID      its key id
#   APPLE_API_ISSUER_ID   its issuer id
#   SPARKLE_KEY_FILE      Sparkle's private EdDSA key, exported with `generate_keys -x`.
#                         Without it, sign_update reads the key from your keychain (account "perch").
set -euo pipefail
here=${0:A:h:h}
name=Perch
repo=Joker666/Perch
version=${VERSION:?set VERSION, like VERSION=1.0.0}
build=${BUILD:-$(date -u +%Y%m%d%H%M)}
dist="$here/dist"
sparkle_bin="$HOME/Library/Developer/$name/build/artifacts/sparkle/Sparkle/bin"

rm -rf "$dist"
mkdir -p "$dist"

# 1. The app, signed with Developer ID and the hardened runtime when there is one.
APP_DIR="$dist" VERSION="$version" BUILD="$build" SIGN_IDENTITY="${DEVELOPER_ID:-}" "$here/build.sh"
app="$dist/$name.app"

# 2. The disk image: the app and a link to Applications.
stage="$dist/dmg"
mkdir -p "$stage"
ditto "$app" "$stage/$name.app"
ln -s /Applications "$stage/Applications"
dmg="$dist/$name.dmg"
hdiutil create -volname "$name" -srcfolder "$stage" -ov -format UDZO "$dmg" >/dev/null
rm -rf "$stage"
[[ -n "${DEVELOPER_ID:-}" ]] && codesign --force --sign "$DEVELOPER_ID" --timestamp "$dmg"

# 3. Notarize and staple, so Gatekeeper opens it without a warning.
if [[ -n "${DEVELOPER_ID:-}" && -n "${APPLE_API_KEY_PATH:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]]; then
  xcrun notarytool submit "$dmg" --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER_ID" --wait
  xcrun stapler staple "$dmg"
  echo "notarized $dmg"
else
  echo "not notarized: set DEVELOPER_ID and the APPLE_API_KEY_* values to notarize"
fi

# 4. Sign the update for Sparkle. The app only installs updates with this signature.
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then
  signature=$("$sparkle_bin/sign_update" --ed-key-file "$SPARKLE_KEY_FILE" "$dmg")
else
  signature=$("$sparkle_bin/sign_update" --account perch "$dmg")
fi

# 5. The appcast on the project site points at this release.
pub_date=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")
cat > "$here/site/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$name</title>
    <link>https://joker666.github.io/$name/appcast.xml</link>
    <description>Updates for $name, a tiny floating todo list for the Mac.</description>
    <language>en</language>
    <item>
      <title>Version $version</title>
      <pubDate>$pub_date</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/$repo/releases/tag/v$version</sparkle:releaseNotesLink>
      <enclosure url="https://github.com/$repo/releases/download/v$version/$name.dmg"
                 type="application/octet-stream" $signature />
    </item>
  </channel>
</rss>
EOF
echo "released $version ($build): $dmg"
