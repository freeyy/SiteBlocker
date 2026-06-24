#!/bin/bash
# Build everything and assemble SiteBlocker.app (a self-contained macOS application bundle).
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

APP_BUNDLE="$BUILD/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

BUNDLE_ID="com.siteblocker.app"
VERSION="1.0"

# --- compile -------------------------------------------------------------------------------
build_core

echo "▸ building $HELPER_NAME"
swiftc "${COMMON_FLAGS[@]}" -I "$BUILD" -L "$BUILD" -l"$CORE_NAME" \
    -o "$BUILD/$HELPER_NAME" "$SOURCES/$HELPER_NAME"/*.swift

echo "▸ building $APP_NAME (GUI)"
swiftc "${COMMON_FLAGS[@]}" -parse-as-library -I "$BUILD" -L "$BUILD" -l"$CORE_NAME" \
    -o "$BUILD/$APP_NAME" "$SOURCES/SiteBlockerApp"/*.swift

# --- assemble bundle -----------------------------------------------------------------------
echo "▸ assembling $APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BUILD/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$BUILD/$HELPER_NAME" "$RES_DIR/$HELPER_NAME"
cp "$ROOT/Scripts/install-service.sh" "$RES_DIR/install-service.sh"
cp "$ROOT/Scripts/uninstall-service.sh" "$RES_DIR/uninstall-service.sh"
chmod 755 "$RES_DIR/$HELPER_NAME" "$RES_DIR/install-service.sh" "$RES_DIR/uninstall-service.sh"

# App icon, if one has been generated.
if [ -f "$BUILD/AppIcon.icns" ]; then
    cp "$BUILD/AppIcon.icns" "$RES_DIR/AppIcon.icns"
    ICON_KEY='<key>CFBundleIconFile</key><string>AppIcon</string>'
else
    ICON_KEY=''
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    $ICON_KEY
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS/PkgInfo"

# Ad-hoc code signature so macOS will launch the locally-built bundle without complaint.
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 \
        && echo "▸ ad-hoc signed" || echo "▸ (codesign skipped)"
fi

echo "✓ packaged: $APP_BUNDLE"
