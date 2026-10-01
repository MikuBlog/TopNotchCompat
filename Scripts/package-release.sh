#!/bin/zsh -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/TopNotchCompat.app"
DIST="$ROOT/dist"

"$ROOT/Scripts/build-app.sh"
mkdir -p "$DIST"
rm -f "$DIST"/TopNotchCompat-*.zip
VERSION="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)"
(cd "$ROOT/build"; ditto -c -k --sequesterRsrc --keepParent "$APP:t" "$DIST/TopNotchCompat-$VERSION-macOS.zip")

echo "$DIST/TopNotchCompat-$VERSION-macOS.zip"
