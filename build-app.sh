#!/bin/bash
set -e

APP_NAME="GlassPlayer"
BUNDLE_ID="com.local.glassplayer"
EXECUTABLE="GlassPlayer"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
ENTITLEMENTS_FILE="${APP_NAME}.entitlements"

echo "Building release binary..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
    echo "App icon added."
fi

cat > "${APP_DIR}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>GlassPlayer</string>
    <key>CFBundleDisplayName</key>
    <string>GlassPlayer</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.glassplayer</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>GlassPlayer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

# Entitlements for WebKit network access (committed in repo)
if [ ! -f "${ENTITLEMENTS_FILE}" ]; then
    echo "Error: ${ENTITLEMENTS_FILE} not found." >&2
    exit 1
fi

# Ad-hoc code signing (allows local execution without Gatekeeper blocking)
echo "Code signing (ad-hoc)..."
codesign --force --sign - --entitlements "${ENTITLEMENTS_FILE}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"
codesign --force --sign - --entitlements "${ENTITLEMENTS_FILE}" "${APP_DIR}"

echo ""
echo "Done! App bundle created at: $(pwd)/${APP_DIR}"
echo ""
echo "To install, run:"
echo "  cp -r \"${APP_DIR}\" /Applications/"
echo ""
echo "Or just double-click \"${APP_DIR}\" in Finder to launch it."
echo ""
echo "For distribution with notarization, replace '--sign -' with your Developer ID:"
echo "  codesign --force --options runtime --sign \"Developer ID Application: ...\" ${APP_DIR}"
echo "  xcrun notarytool submit ... --wait"
echo "  xcrun stapler staple ${APP_DIR}"
