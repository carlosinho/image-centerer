#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Owlign"
PRODUCT_NAME="ImageCenterer"
BUNDLE_ID="com.local.owlign-image-centerer"
# Version comes from the first argument, else the VERSION file at the repo root.
VERSION="${1:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION" 2>/dev/null || echo "0.0.0-dev")}"

DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$ROOT_DIR/app-icon.png"
ICONSET_DIR="$DIST_DIR/ImageCenterer.iconset"
ICON_FILE="ImageCenterer.icns"

cd "$ROOT_DIR"

echo "Building $PRODUCT_NAME release binary..."
swift build -c release --product "$PRODUCT_NAME"

echo "Creating app bundle..."
rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/$PRODUCT_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -f "$ICON_SOURCE" ]]; then
    if ! command -v iconutil >/dev/null 2>&1; then
        echo "error: iconutil is required to create the app icon." >&2
        exit 1
    fi

    echo "Creating app icon..."
    mkdir -p "$ICONSET_DIR"
    TMP_ICON_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_ICON_DIR"' EXIT

    ICON_WIDTH="$(sips -g pixelWidth "$ICON_SOURCE" | awk '/pixelWidth/ {print $2}')"
    ICON_HEIGHT="$(sips -g pixelHeight "$ICON_SOURCE" | awk '/pixelHeight/ {print $2}')"
    ICON_SIZE="$ICON_WIDTH"
    if [[ "$ICON_HEIGHT" -gt "$ICON_SIZE" ]]; then
        ICON_SIZE="$ICON_HEIGHT"
    fi

    sips --padToHeightWidth "$ICON_SIZE" "$ICON_SIZE" --padColor FFFFFF "$ICON_SOURCE" --out "$TMP_ICON_DIR/icon-square.png" >/dev/null

    sips -z 16 16 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -z 32 32 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -z 64 64 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -z 256 256 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -z 512 512 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$TMP_ICON_DIR/icon-square.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/$ICON_FILE"
    rm -rf "$ICONSET_DIR"
else
    echo "No app-icon.png found; building app without a custom icon."
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_FILE</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
    echo "Applying ad-hoc signature..."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "Done."
echo "App: $APP_DIR"
