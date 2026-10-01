#!/bin/zsh -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/TopNotchCompat.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"
swift build -c release --product TopNotchCompat

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp .build/release/TopNotchCompat "$MACOS/TopNotchCompat"
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"
codesign --force --sign - "$APP"

echo "$APP"
