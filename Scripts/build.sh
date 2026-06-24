#!/bin/bash
# Build the core library, the helper, and the GUI app executable into $BUILD.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

build_core

echo "▸ building $HELPER_NAME"
swiftc "${COMMON_FLAGS[@]}" -I "$BUILD" -L "$BUILD" -l"$CORE_NAME" \
    -o "$BUILD/$HELPER_NAME" \
    "$SOURCES/$HELPER_NAME"/*.swift

echo "▸ building $APP_NAME (GUI)"
swiftc "${COMMON_FLAGS[@]}" -parse-as-library -I "$BUILD" -L "$BUILD" -l"$CORE_NAME" \
    -o "$BUILD/$APP_NAME" \
    "$SOURCES/SiteBlockerApp"/*.swift

echo "✓ build complete: $BUILD/$APP_NAME, $BUILD/$HELPER_NAME"
