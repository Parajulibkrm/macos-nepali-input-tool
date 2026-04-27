#!/usr/bin/env bash
set -euo pipefail

# Build a signed-or-unsigned macOS installer .pkg for GoogleInputTools.
#
# Usage: build-pkg.sh <app-path> <swiftsupport-dir> <arch> <version> <output-pkg>
#   app-path         Path to GoogleInputTools.app
#   swiftsupport-dir Directory containing *.swiftmodule (may be empty)
#   arch             x86_64 | arm64
#   version          Version string for the package (e.g. 2026.04.27)
#   output-pkg       Destination .pkg path

if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <app-path> <swiftsupport-dir> <arch> <version> <output-pkg>" >&2
  exit 1
fi

APP_PATH="$1"
SWIFT_SUPPORT="$2"
ARCH="$3"
VERSION="$4"
OUTPUT="$5"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PAYLOAD="$WORK/payload"
mkdir -p "$PAYLOAD"

cp -R "$APP_PATH" "$PAYLOAD/"

if [ -d "$SWIFT_SUPPORT" ] && [ -n "$(ls -A "$SWIFT_SUPPORT" 2>/dev/null)" ]; then
  cp -R "$SWIFT_SUPPORT" "$PAYLOAD/SwiftSupport"
fi

COMPONENT_PKG="$WORK/component.pkg"
pkgbuild \
  --root "$PAYLOAD" \
  --identifier "com.lennylxx.inputmethod.GoogleInputTools" \
  --version "$VERSION" \
  --install-location "/Library/Input Methods" \
  --scripts "$SCRIPT_DIR/scripts" \
  "$COMPONENT_PKG"

DIST_XML="$WORK/distribution.xml"
cat > "$DIST_XML" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Google Input Tools</title>
  <organization>com.lennylxx.inputmethod</organization>
  <domains enable_localSystem="true"/>
  <options customize="never" require-scripts="true" hostArchitectures="${ARCH}"/>
  <welcome file="welcome.html" mime-type="text/html"/>
  <conclusion file="conclusion.html" mime-type="text/html"/>
  <choices-outline>
    <line choice="default">
      <line choice="com.lennylxx.inputmethod.GoogleInputTools"/>
    </line>
  </choices-outline>
  <choice id="default"/>
  <choice id="com.lennylxx.inputmethod.GoogleInputTools" visible="false">
    <pkg-ref id="com.lennylxx.inputmethod.GoogleInputTools"/>
  </choice>
  <pkg-ref id="com.lennylxx.inputmethod.GoogleInputTools" version="${VERSION}" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
EOF

productbuild \
  --distribution "$DIST_XML" \
  --resources "$SCRIPT_DIR/resources" \
  --package-path "$WORK" \
  "$OUTPUT"

echo "Built ${OUTPUT}"
