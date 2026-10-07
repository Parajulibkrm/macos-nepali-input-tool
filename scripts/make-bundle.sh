#!/usr/bin/env bash
# Builds the input method bundle.
# Usage: make-bundle.sh <output-dir> [--universal]
# Produces <dir>/<name>.app (the input method) and <dir>/launcher/<name>.app (the Spotlight entry).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/config.sh

OUT="$1"
if [ "${2:-}" = "--universal" ]; then
  swift build -c release --arch arm64 --arch x86_64
  BINDIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
else
  swift build -c release
  BINDIR=".build/release"
fi

APP="$OUT/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BINDIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
sed -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" -e "s|__APP_NAME__|$APP_NAME|g" -e "s|__EXECUTABLE__|$EXECUTABLE|g" \
    -e "s|__VERSION__|$VERSION|g" -e "s|__BUILD_NUMBER__|$BUILD_NUMBER|g" \
    Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint -s "$APP/Contents/Info.plist"

LAUNCHER="$OUT/launcher/$APP_NAME.app"
rm -rf "$OUT/launcher"
mkdir -p "$LAUNCHER/Contents/MacOS"
cp "$BINDIR/${EXECUTABLE}Launcher" "$LAUNCHER/Contents/MacOS/${EXECUTABLE}Launcher"
sed -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" -e "s|__APP_NAME__|$APP_NAME|g" -e "s|__EXECUTABLE__|$EXECUTABLE|g" \
    -e "s|__VERSION__|$VERSION|g" -e "s|__BUILD_NUMBER__|$BUILD_NUMBER|g" \
    Resources/Launcher-Info.plist > "$LAUNCHER/Contents/Info.plist"
plutil -lint -s "$LAUNCHER/Contents/Info.plist"
echo "$APP"
