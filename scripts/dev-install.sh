#!/usr/bin/env bash
# Builds, signs with your Apple Development identity and installs into ~/Library/Input Methods.
# A stable signing identity keeps the Microphone and Accessibility permissions across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/config.sh

# The first match can change when the keychain changes, and a different identity resets the
# granted permissions, so set IDENTITY (or SIGNING_HINT) to pin one.
IDENTITY="${IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 "Apple Development.*${SIGNING_HINT:-}" | sed -E 's/.*"(.*)"/\1/')}"
DEST="$HOME/Library/Input Methods"

APP="$(scripts/make-bundle.sh .build/bundle | tail -1)"
codesign --force --options runtime --entitlements Resources/NepaliInput.entitlements --sign "$IDENTITY" "$APP"

killall "$EXECUTABLE" 2>/dev/null || true
rm -rf "$DEST/$APP_NAME.app"
cp -R "$APP" "$DEST/"
echo "Installed $DEST/$APP_NAME.app (signed by $IDENTITY)"
echo "First time: System Settings → Keyboard → Input Sources → + → Nepali → $APP_NAME"
