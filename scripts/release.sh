#!/usr/bin/env bash
# Builds a universal, signed and notarized installer into dist/.
# Env (all optional; without them you get an unsigned pkg for local testing):
#   APP_IDENTITY        "Developer ID Application: …"
#   INSTALLER_IDENTITY  "Developer ID Installer: …"
#   NOTARY_PROFILE      keychain profile from `xcrun notarytool store-credentials`
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/config.sh

APP_IDENTITY="${APP_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 'Developer ID Application' | sed -E 's/.*"(.*)"/\1/' || true)}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-$(security find-identity -v | grep -m1 'Developer ID Installer' | sed -E 's/.*"(.*)"/\1/' || true)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

mkdir -p dist
APP="$(scripts/make-bundle.sh dist/bundle --universal | tail -1)"

if [ -n "$APP_IDENTITY" ]; then
  codesign --force --timestamp --options runtime --entitlements Resources/NepaliInput.entitlements --sign "$APP_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  echo "warning: no Developer ID Application identity, app is unsigned" >&2
fi

PKG="dist/$EXECUTABLE-$VERSION.pkg"
packaging/pkg/build-pkg.sh "$APP" "$PKG" "$INSTALLER_IDENTITY"

if [ -n "$INSTALLER_IDENTITY" ] && [ -n "$NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$PKG"
else
  echo "warning: pkg not notarized (needs INSTALLER_IDENTITY and NOTARY_PROFILE)" >&2
fi

shasum -a 256 "$PKG"
echo "$PKG"
