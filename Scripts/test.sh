#!/bin/bash
# Build and run the unit test suite.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

build_core

echo "▸ building test runner"
swiftc "${COMMON_FLAGS[@]}" -I "$BUILD" -L "$BUILD" -l"$CORE_NAME" \
    -o "$BUILD/siteblocker-tests" \
    "$SOURCES/SiteBlockerTests"/*.swift

echo "▸ running tests"
"$BUILD/siteblocker-tests"
