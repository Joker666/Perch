#!/bin/zsh
# Builds a release: dist/Perch.app, dist/Perch.dmg, dist/notes.md, and site/appcast.xml.
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
#   RELEASE_NOTES         a file of "- " lines to use as the notes instead of the commit subjects
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

# 5. Release notes: the commit subjects since the last tag. Commit messages say what people can
# now do, so they read as notes. RELEASE_NOTES=<file> uses a hand-written list of "- " lines instead.
ref="v$version"
git -C "$here" rev-parse -q --verify "$ref" >/dev/null || ref=HEAD
prev=$(git -C "$here" describe --tags --abbrev=0 --match 'v*' "$ref^" 2>/dev/null || true)
notes="$dist/notes.md"
if [[ -n "${RELEASE_NOTES:-}" ]]; then
  cp "$RELEASE_NOTES" "$notes"
else
  git -C "$here" log --no-merges --format='- %s' "${prev:+$prev..}$ref" | grep -v '^- Point the appcast at' | head -20 > "$notes" || true
fi
[[ -s "$notes" ]] || echo "- Bug fixes and small improvements." > "$notes"
# The same list as HTML, shown in Sparkle's update window. The GitHub page is only a link,
# because a releaseNotesLink would load the whole GitHub site into that window.
items=$(sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/^- \(.*\)$/<li>\1<\/li>/' "$notes" | tr -d '\n')
style='<style>:root{color-scheme:light dark}body{font:13px/1.45 -apple-system,sans-serif;margin:0 4px}ul{padding-left:18px;margin:8px 0}li{margin:4px 0}</style>'

# 6. The appcast on the project site points at this release.
pub_date=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")
cat > "$here/site/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$name</title>
    <link>https://rafihasan.com/$name/appcast.xml</link>
    <description>Updates for $name, a tiny floating todo list for the Mac.</description>
    <language>en</language>
    <item>
      <title>Version $version</title>
      <pubDate>$pub_date</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <description><![CDATA[$style<ul>$items</ul>]]></description>
      <sparkle:fullReleaseNotesLink>https://github.com/$repo/releases/tag/v$version</sparkle:fullReleaseNotesLink>
      <enclosure url="https://github.com/$repo/releases/download/v$version/$name.dmg"
                 type="application/octet-stream" $signature />
    </item>
  </channel>
</rss>
EOF
echo "released $version ($build): $dmg"
