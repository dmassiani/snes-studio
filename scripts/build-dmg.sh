#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# build-dmg.sh — Build, sign, notarize, and package SNES Studio as a DMG
#
# Prerequisites:
#   - Xcode + Command Line Tools
#   - xcodegen (brew install xcodegen)
#   - Node.js + npm
#   - A "Developer ID Application" certificate in your keychain
#
# Environment variables (required for notarization):
#   APPLE_ID              — Apple Developer email
#   APPLE_ID_PASSWORD     — App-specific password
#   APPLE_TEAM_ID         — Team ID (e.g. JD74ATC9J8)
#
# Optional:
#   DEVELOPER_ID_NAME     — Signing identity (default: auto-detect)
# ------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="SNES Studio"
SCHEME="SNESStudio"
ARCHIVE_PATH="$PROJECT_DIR/build/SNESStudio.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/export"
DMG_DIR="$PROJECT_DIR/build/dmg"

# Read version from project.yml
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_DIR/project.yml" | head -1 | sed 's/.*: *"\(.*\)"/\1/')
DMG_NAME="SNESStudio-${VERSION}.dmg"
DMG_PATH="$PROJECT_DIR/build/$DMG_NAME"

# Auto-detect Developer ID signing identity if not set
if [ -z "${DEVELOPER_ID_NAME:-}" ]; then
    DEVELOPER_ID_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
    if [ -z "$DEVELOPER_ID_NAME" ]; then
        echo "Error: No Developer ID Application certificate found in keychain."
        exit 1
    fi
fi

echo "==> Building SNES Studio v${VERSION}"
echo "    Signing identity: ${DEVELOPER_ID_NAME}"

# ------------------------------------------------------------------
# Step 1: Generate Xcode project
# ------------------------------------------------------------------
echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

# ------------------------------------------------------------------
# Step 2: Build CodeMirror editor bundle
# ------------------------------------------------------------------
echo "==> Building CodeMirror bundle..."
cd "$PROJECT_DIR/codemirror-build"
npm ci
npm run build

# ------------------------------------------------------------------
# Step 3: Archive the app
# ------------------------------------------------------------------
echo "==> Archiving..."
cd "$PROJECT_DIR"
xcodebuild archive \
    -project SNESStudio.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_NAME" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    SKIP_INSTALL=NO \
    | xcpretty || xcodebuild archive \
    -project SNESStudio.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_NAME" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    SKIP_INSTALL=NO

# ------------------------------------------------------------------
# Step 4: Export the signed app
# ------------------------------------------------------------------
echo "==> Exporting signed app..."

# Create export options plist
EXPORT_OPTIONS="$PROJECT_DIR/build/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-JD74ATC9J8}</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

# ------------------------------------------------------------------
# Step 5: Create DMG
# ------------------------------------------------------------------
echo "==> Creating DMG..."
rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR"

cp -R "$EXPORT_PATH/$APP_NAME.app" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# ------------------------------------------------------------------
# Step 6: Notarize
# ------------------------------------------------------------------
echo "==> Notarizing DMG..."
if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_ID_PASSWORD:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
    echo "Warning: APPLE_ID, APPLE_ID_PASSWORD, or APPLE_TEAM_ID not set. Skipping notarization."
    echo "==> Done (unsigned DMG): $DMG_PATH"
    exit 0
fi

xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_ID_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

# ------------------------------------------------------------------
# Step 7: Staple
# ------------------------------------------------------------------
echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "==> Done: $DMG_PATH"
