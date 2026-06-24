#!/bin/bash
# Generate build/AppIcon.icns from a SwiftUI-rendered master image.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MASTER="$BUILD/AppIcon-master.png"
ICONSET="$BUILD/AppIcon.iconset"

echo "▸ rendering icon master"
swiftc "${COMMON_FLAGS[@]}" -parse-as-library "$ROOT/Scripts/IconGen.swift" -o "$BUILD/icongen"
"$BUILD/icongen" "$MASTER"

echo "▸ building iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
gen() { sips -z "$2" "$2" "$MASTER" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png 16
gen icon_16x16@2x.png 32
gen icon_32x32.png 32
gen icon_32x32@2x.png 64
gen icon_128x128.png 128
gen icon_128x128@2x.png 256
gen icon_256x256.png 256
gen icon_256x256@2x.png 512
gen icon_512x512.png 512
gen icon_512x512@2x.png 1024

iconutil -c icns "$ICONSET" -o "$BUILD/AppIcon.icns"
echo "✓ wrote $BUILD/AppIcon.icns"
