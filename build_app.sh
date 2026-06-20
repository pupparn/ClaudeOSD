#!/bin/bash
# Builds Claude Usage OSD.app and installs it to ~/Applications so it can be
# launched by double-click (Finder/Spotlight/Dock) without the command line.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Claude Usage OSD"
BIN_NAME="ClaudeUsageOSD"
DEST_DIR="$HOME/Applications"
APP_BUNDLE="$DEST_DIR/$APP_NAME.app"

echo "Building release binary..."
swift build -c release

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp ".build/release/$BIN_NAME" "$APP_BUNDLE/Contents/MacOS/$BIN_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

mkdir -p "$DEST_DIR"
echo "Installed: $APP_BUNDLE"

echo "Ensuring login item is registered..."
osascript <<EOF
tell application "System Events"
    if not (exists login item "$APP_NAME") then
        make new login item at end of login items with properties {path:"$APP_BUNDLE", hidden:false}
    end if
end tell
EOF

echo "Launch from Finder > ~/Applications, or run: open \"$APP_BUNDLE\""
