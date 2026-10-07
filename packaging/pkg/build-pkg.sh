#!/usr/bin/env bash
set -euo pipefail

# Builds the installer .pkg (universal, one package for both architectures).
# Usage: build-pkg.sh <app-path> <output-pkg> [installer-identity]
#   installer-identity  "Developer ID Installer: …"; the pkg is left unsigned when omitted.
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <app-path> <output-pkg> [installer-identity]" >&2
  exit 1
fi

APP_PATH="$1"
OUTPUT="$2"
IDENTITY="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/config.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PAYLOAD="$WORK/payload"
mkdir -p "$PAYLOAD"
cp -R "$APP_PATH" "$PAYLOAD/"
chmod +x "$PAYLOAD/$(basename "$APP_PATH")/Contents/MacOS/$EXECUTABLE"

# Fill the app name into the installer text.
RES="$WORK/resources"
mkdir -p "$RES"
for f in "$SCRIPT_DIR"/resources/*.html; do
  sed -e "s|__APP_NAME__|$APP_NAME|g" -e "s|__EXECUTABLE__|$EXECUTABLE|g" "$f" > "$RES/$(basename "$f")"
done

# The postinstall script gets the identifiers it needs baked in.
SCRIPTS="$WORK/scripts"
mkdir -p "$SCRIPTS"
sed -e "s|__APP_NAME__|$APP_NAME|g" -e "s|__EXECUTABLE__|$EXECUTABLE|g" -e "s|__LEGACY_APP__|$LEGACY_APP|g" \
    -e "s|__LEGACY_EXECUTABLE__|$LEGACY_EXECUTABLE|g" -e "s|__LEGACY_PKG_ID__|$LEGACY_PKG_ID|g" \
    "$SCRIPT_DIR/scripts/postinstall" > "$SCRIPTS/postinstall"
chmod +x "$SCRIPTS/postinstall"

pkgbuild \
  --root "$PAYLOAD" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  --install-location "/Library/Input Methods" \
  --scripts "$SCRIPTS" \
  "$WORK/component.pkg"

cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>$APP_NAME</title>
  <organization>io.veez</organization>
  <domains enable_localSystem="true"/>
  <options customize="never" require-scripts="true" hostArchitectures="arm64,x86_64"/>
  <welcome file="welcome.html" mime-type="text/html"/>
  <conclusion file="conclusion.html" mime-type="text/html"/>
  <choices-outline>
    <line choice="default">
      <line choice="$BUNDLE_ID"/>
    </line>
  </choices-outline>
  <choice id="default"/>
  <choice id="$BUNDLE_ID" visible="false">
    <pkg-ref id="$BUNDLE_ID"/>
  </choice>
  <pkg-ref id="$BUNDLE_ID" version="$VERSION" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
XML

SIGN=()
[ -n "$IDENTITY" ] && SIGN=(--sign "$IDENTITY" --timestamp)

productbuild \
  --distribution "$WORK/distribution.xml" \
  --resources "$RES" \
  --package-path "$WORK" \
  ${SIGN[@]+"${SIGN[@]}"} \
  "$OUTPUT"

echo "Built $OUTPUT"
