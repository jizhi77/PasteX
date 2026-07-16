#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.0.2}"
ARCH="arm64"
PRODUCT="PasteX"
DIST="$ROOT/dist"
APP="$DIST/$PRODUCT.app"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$PRODUCT" "$APP/Contents/MacOS/$PRODUCT"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDisplayName</key><string>PasteX</string>
  <key>CFBundleExecutable</key><string>PasteX</string>
  <key>CFBundleIdentifier</key><string>com.pastex.app</string>
  <key>CFBundleName</key><string>PasteX</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

chmod +x "$APP/Contents/MacOS/$PRODUCT"
codesign --force --deep --sign "${SIGNING_IDENTITY:--}" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
rm -f "$DIST/$PRODUCT-v$VERSION-macos-$ARCH.zip"
(
  cd "$DIST"
  COPYFILE_DISABLE=1 zip -qryX "$PRODUCT-v$VERSION-macos-$ARCH.zip" "$PRODUCT.app"
)
echo "Created $DIST/$PRODUCT-v$VERSION-macos-$ARCH.zip"
