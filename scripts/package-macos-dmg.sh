#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This packaging script requires macOS." >&2
  exit 1
fi

if [[ -n "${FIELD_VERSION:-}" ]]; then
  VERSION="$FIELD_VERSION"
elif [[ "${GITHUB_REF_NAME:-}" == v* ]]; then
  VERSION="${GITHUB_REF_NAME#v}"
else
  VERSION="0.1.0"
fi
BUILD_NUMBER="${FIELD_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
BUNDLE_IDENTIFIER="${FIELD_BUNDLE_IDENTIFIER:-com.fieldlab.field}"

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "FIELD_VERSION must contain one to three numeric components (for example 0.1.0)." >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "FIELD_BUILD_NUMBER must contain one to three numeric components." >&2
  exit 1
fi

if [[ ! "$BUNDLE_IDENTIFIER" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "FIELD_BUNDLE_IDENTIFIER contains invalid characters." >&2
  exit 1
fi

for tool in swift hdiutil sips iconutil; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required macOS tool not found: $tool" >&2
    exit 1
  fi
done

BUILD_ROOT="$ROOT_DIR/.build/dmg"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$BUILD_ROOT" "$DIST_DIR"

swift build --configuration release --product FIELD \
  --triple arm64-apple-macosx14.0 \
  --scratch-path "$BUILD_ROOT/swift-arm64"
ARM64_BIN_DIR="$(swift build --configuration release --product FIELD \
  --triple arm64-apple-macosx14.0 \
  --scratch-path "$BUILD_ROOT/swift-arm64" --show-bin-path)"
if [[ ! -x "$ARM64_BIN_DIR/FIELD" ]]; then
  echo "FIELD executable missing from build output: $ARM64_BIN_DIR" >&2
  exit 1
fi

if [[ ! -d "$ARM64_BIN_DIR/FIELD_FIELD.bundle" ]]; then
  echo "Swift package resources missing from build output." >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/field-dmg.XXXXXX")"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

APP_PATH="$STAGING_DIR/FIELD LAB.app"
CONTENTS_DIR="$APP_PATH/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$CONTENTS_DIR/MacOS" "$RESOURCES_DIR"

cp "$ARM64_BIN_DIR/FIELD" "$CONTENTS_DIR/MacOS/FIELD"
chmod 755 "$CONTENTS_DIR/MacOS/FIELD"
cp -R "$ARM64_BIN_DIR/FIELD_FIELD.bundle" "$RESOURCES_DIR/"

ICON_SOURCE="$ROOT_DIR/Sources/FIELD/Resources/FIELDLogo.png"
ICONSET_DIR="$RESOURCES_DIR/FIELD.iconset"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil --convert icns "$ICONSET_DIR" --output "$RESOURCES_DIR/FIELD.icns"
rm -rf "$ICONSET_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>FIELD</string>
  <key>CFBundleIconFile</key>
  <string>FIELD.icns</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_IDENTIFIER}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>FIELD LAB</string>
  <key>CFBundleDisplayName</key>
  <string>FIELD LAB</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat > "$STAGING_DIR/INSTALL.txt" <<'INSTALL'
FIELD LAB — macOS preview

1. Drag FIELD LAB.app to Applications.
2. Eject this disk image and open FIELD LAB from Applications.

Requires macOS 14 or later. This preview is unsigned and not notarized. If
macOS blocks the first launch, only continue if this image came from the
official repository and you trust the project. Open the app once, then use
System Settings > Privacy & Security > Open Anyway to approve it.

The iPhone app and iCloud sync are not available yet. FIELD LAB currently
stores its data locally on this Mac.
INSTALL

ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$DIST_DIR/FIELD-LAB-macOS-${VERSION}-apple-silicon-unsigned.dmg"
rm -f "$DMG_PATH" "$DMG_PATH.sha256"
hdiutil create -volname "FIELD LAB" -srcfolder "$STAGING_DIR" \
  -format UDZO -ov "$DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null
(cd "$DIST_DIR" && shasum -a 256 "$(basename "$DMG_PATH")") > "$DMG_PATH.sha256"

echo "Created: $DMG_PATH"
file "$CONTENTS_DIR/MacOS/FIELD"
echo "SHA-256: $DMG_PATH.sha256"
