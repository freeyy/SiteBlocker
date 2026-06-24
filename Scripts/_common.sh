#!/bin/bash
# Shared build configuration. Sourced by the other scripts.
#
# We drive `swiftc` directly (rather than `swift build`). As a bonus this transparently works
# around a duplicate `SwiftBridging` module map present in some Command Line Tools installs, via a
# clang VFS overlay that is applied ONLY when the stale module map is detected (a no-op otherwise).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
SOURCES="$ROOT/Sources"

CORE_NAME="SiteBlockerCore"
APP_NAME="SiteBlocker"
HELPER_NAME="site-blocker-helper"

DEPLOYMENT_TARGET="arm64-apple-macosx13.0"

mkdir -p "$BUILD"

# --- VFS overlay to mask the stale duplicate module.modulemap -----------------------------
STALE_MODULEMAP="/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap"
OVERLAY="$BUILD/vfs-overlay.yaml"
EMPTY_MODULEMAP="$BUILD/empty.modulemap"

setup_overlay() {
    : > "$EMPTY_MODULEMAP"
    if [ -f "$STALE_MODULEMAP" ] && [ -f "/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap" ]; then
        cat > "$OVERLAY" <<EOF
{
  "version": 0,
  "case-sensitive": false,
  "roots": [
    {
      "type": "directory",
      "name": "/Library/Developer/CommandLineTools/usr/include/swift",
      "contents": [
        { "type": "file", "name": "module.modulemap", "external-contents": "$EMPTY_MODULEMAP" }
      ]
    }
  ]
}
EOF
        # Both forms are required: the swift-level -vfsoverlay threads the overlay through to
        # sub-invocations (e.g. building the SwiftBridging clang module that SwiftUI pulls in),
        # while -Xcc -ivfsoverlay covers the main clang importer pass.
        SWIFTC_OVERLAY_FLAGS=(-vfsoverlay "$OVERLAY" -Xcc -ivfsoverlay -Xcc "$OVERLAY")
    else
        # Healthy toolchain: no overlay needed.
        SWIFTC_OVERLAY_FLAGS=()
    fi
}

setup_overlay

# Common flags for every swiftc invocation.
COMMON_FLAGS=(-target "$DEPLOYMENT_TARGET" -O "${SWIFTC_OVERLAY_FLAGS[@]}")

# Build the SiteBlockerCore module + static library into $BUILD.
build_core() {
    echo "▸ building $CORE_NAME"
    swiftc "${COMMON_FLAGS[@]}" -parse-as-library \
        -emit-module -module-name "$CORE_NAME" \
        -emit-module-path "$BUILD/$CORE_NAME.swiftmodule" \
        -emit-library -static -o "$BUILD/lib$CORE_NAME.a" \
        "$SOURCES/$CORE_NAME"/*.swift
}
