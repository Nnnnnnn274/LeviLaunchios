#!/bin/bash
# Quick build script for LeviLauncher iOS dylib

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building LeviLauncher dylib for iOS..."

xcodebuild -project LeviLauncher.xcodeproj \
           -scheme LeviLauncher \
           -configuration Release \
           -sdk iphoneos \
           CODE_SIGNING_ALLOWED=NO \
           clean build 2>&1 | tail -20

echo ""
echo "Build complete. Finding dylib..."

DYLIB_PATH=$(find ~/Library/Developer/Xcode/DerivedData \
                 -name "LeviLauncher.framework" \
                 -path "*/Release-iphoneos/*" \
                 -type d \
                 | head -1)

if [ -n "$DYLIB_PATH" ]; then
    cp -R "$DYLIB_PATH" "$SCRIPT_DIR/build/"
    echo "Copied to: $SCRIPT_DIR/build/LeviLauncher.framework"
    ls -lh "$SCRIPT_DIR/build/LeviLauncher.framework/LeviLauncher"
else
    echo "Could not locate built framework in DerivedData"
fi
