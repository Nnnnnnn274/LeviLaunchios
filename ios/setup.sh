#!/bin/bash
# LeviLauncher iOS Setup Script
# Sets up the build environment and generates Xcode project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== LeviLauncher iOS Setup ==="
echo ""

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "[1/3] Installing XcodeGen..."
    brew install xcodegen
else
    echo "[1/3] XcodeGen already installed"
fi

# Generate Xcode project
echo "[2/3] Generating Xcode project..."
cd "$SCRIPT_DIR"
xcodegen generate --spec project.yml
echo "    Generated: LeviLauncher.xcodeproj"

# Check for required tools
echo "[3/3] Checking tools..."
TOOLS_OK=true

if ! command -v ldid &> /dev/null; then
    echo "    WARNING: ldid not found (needed for re-signing)"
    echo "    Install: brew install ldid"
    TOOLS_OK=false
fi

if ! command -v optool &> /dev/null && ! command -v insert_dylib &> /dev/null; then
    echo "    WARNING: optool/insert_dylib not found (needed for injection)"
    echo "    Install: brew install optool"
    TOOLS_OK=false
fi

if ! command -v ideviceinstaller &> /dev/null && ! command -v ios-deploy &> /dev/null; then
    echo "    WARNING: No installation tool found"
    echo "    Install: brew install ideviceinstaller"
    TOOLS_OK=false
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Build the dylib:"
echo "     xcodebuild -project LeviLauncher.xcodeproj -scheme LeviLauncher -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO"
echo ""
echo "  2. Inject into Minecraft IPA:"
echo "     ./inject.sh path/to/Minecraft.ipa"
echo ""
echo "  3. Or manually:"
echo "     - Decrypt Minecraft IPA (use frida-ios-dump or similar)"
echo "     - Place the built LeviLauncher.framework into the app's Frameworks/"
echo "     - Use optool to add LC_LOAD_DYLIB to the Minecraft binary"
echo "     - Re-sign with ldid"
echo "     - Install with ideviceinstaller"
echo ""
echo "Requires jailbroken device or TrollStore."
