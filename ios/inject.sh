#!/bin/bash
# LeviLauncher iOS Injection Script
# Injects the LeviLauncher dylib into a decrypted Minecraft IPA
# Requires: ideviceinstaller, ldid, insert_dylib, or optool

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
DYLIB_PATH="$BUILD_DIR/LeviLauncher.framework/LeviLauncher"

echo "=== LeviLauncher iOS Injection Tool ==="
echo ""

# 1. Build the dylib
build_dylib() {
    echo "[1/5] Building LeviLauncher dylib..."
    cd "$SCRIPT_DIR"
    xcodebuild -project LeviLauncher.xcodeproj \
               -scheme LeviLauncher \
               -configuration Release \
               -sdk iphoneos \
               CODE_SIGNING_ALLOWED=NO \
               clean build
    
    # Find the built dylib
    local built_dylib=$(find ~/Library/Developer/Xcode/DerivedData -name "LeviLauncher.framework" -path "*/Release-iphoneos/*" | head -1)
    if [ -z "$built_dylib" ]; then
        echo "ERROR: Could not find built dylib"
        exit 1
    fi
    
    mkdir -p "$BUILD_DIR"
    cp -R "$built_dylib" "$BUILD_DIR/"
    echo "    Built: $DYLIB_PATH"
}

# 2. Download decrypted Minecraft IPA (if not provided)
download_ipa() {
    echo "[2/5] Minecraft IPA..."
    
    IPA_PATH="$BUILD_DIR/Minecraft.ipa"
    
    if [ -f "$1" ]; then
        IPA_PATH="$1"
        echo "    Using provided IPA: $IPA_PATH"
        return
    fi
    
    # Check for existing IPA
    if [ -f "$IPA_PATH" ]; then
        echo "    Using existing IPA: $IPA_PATH"
        return
    fi
    
    # Search Downloads folder for Minecraft IPA
    local downloads_ipa=$(ls ~/Downloads/*.ipa 2>/dev/null | grep -i minecraft | head -1)
    if [ -n "$downloads_ipa" ]; then
        IPA_PATH="$downloads_ipa"
        echo "    Using IPA from Downloads: $IPA_PATH"
        return
    fi
    
    # Try to dump from device
    echo "    Attempting to dump Minecraft from connected device..."
    if command -v frida-ios-dump &> /dev/null; then
        frida-ios-dump -o "$BUILD_DIR" com.mojang.minecraftpe
        mv "$BUILD_DIR"/*.ipa "$IPA_PATH" 2>/dev/null || true
    fi
    
    if [ ! -f "$IPA_PATH" ]; then
        echo "    WARNING: No IPA found. Place a decrypted Minecraft.ipa in $BUILD_DIR/"
        echo "    Or in ~/Downloads/, or provide path: $0 path/to/Minecraft.ipa"
        exit 1
    fi
}

# 3. Extract and inject
inject_dylib() {
    echo "[3/5] Extracting IPA and injecting dylib..."
    
    local work_dir="$BUILD_DIR/Payload"
    rm -rf "$work_dir"
    mkdir -p "$work_dir"
    
    cd "$BUILD_DIR"
    unzip -q "$IPA_PATH" -d "$work_dir/tmp"
    mv "$work_dir/tmp/Payload"/*.app "$work_dir/LeviLauncherInjected.app" 2>/dev/null || \
    mv "$work_dir/tmp/Payload"/* "$work_dir/" 2>/dev/null
    
    local app_path="$work_dir"/*.app
    if [ ! -d "$app_path" ]; then
        echo "ERROR: Could not find .app in IPA payload"
        exit 1
    fi
    
    echo "    App: $app_path"
    
    # Copy dylib into app bundle
    cp -R "$BUILD_DIR/LeviLauncher.framework" "$app_path/Frameworks/"

    # Use optool or insert_dylib to add load command
    local main_binary=$(ls "$app_path" | grep -v '.dylib$' | grep -v '.framework$' | head -1)
    local binary_path="$app_path/$main_binary"
    
    if command -v optool &> /dev/null; then
        optool install -c load -p "@executable_path/Frameworks/LeviLauncher.framework/LeviLauncher" \
               -t "$binary_path"
    elif command -v insert_dylib &> /dev/null; then
        insert_dylib --strip-all --inplace \
            "@executable_path/Frameworks/LeviLauncher.framework/LeviLauncher" \
            "$binary_path"
    else
        echo "ERROR: Need optool or insert_dylib. Install with:"
        echo "  brew install optool"
        exit 1
    fi
    
    echo "    Dylib injected into binary"
}

# 4. Re-sign
resign() {
    echo "[4/5] Re-signing with ldid..."
    
    local app_path="$BUILD_DIR/Payload"/*.app
    
    # Generate entitlements
    ldid -e "$app_path/$(ls "$app_path" | grep -v '.dylib$' | grep -v '.framework$' | head -1)" > "$BUILD_DIR/entitlements.plist" 2>/dev/null || true
    
    # JIT-specific keys to add (merge into existing entitlements)
    cat > "$BUILD_DIR/jit_entitlements.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.dynamic-codesigning</key>
    <true/>
    <key>com.apple.private.cs.debugger</key>
    <true/>
    <key>dynamic-codesigning</key>
    <true/>
    <key>get-task-allow</key>
    <true/>
    <key>task_for_pid-allow</key>
    <true/>
    <key>run-unsigned-code</key>
    <true/>
</dict>
</plist>
EOF

    # Merge JIT entitlements into main entitlements file
    # If existing entitlements file was created by ldid, use plist merging
    if [ -f "$BUILD_DIR/entitlements.plist" ]; then
        # Use PlistBuddy to merge - add any keys from jit_entitlements that aren't already present
        /usr/libexec/PlistBuddy -c "Merge '$BUILD_DIR/jit_entitlements.plist'" "$BUILD_DIR/entitlements.plist" 2>/dev/null || true
    else
        cp "$BUILD_DIR/jit_entitlements.plist" "$BUILD_DIR/entitlements.plist"
    fi
    
    # Sign everything
    ldid -S"$BUILD_DIR/entitlements.plist" "$app_path/LeviLauncher.framework/LeviLauncher"
    find "$app_path" -type f -name "*.dylib" -exec ldid -S {} \;
    ldid -S"$BUILD_DIR/entitlements.plist" "$app_path/$(ls "$app_path" | head -1)"
    
    echo "    Re-signed with fake entitlements"
}

# 5. Install via ideviceinstaller
install() {
    echo "[5/5] Installing to device..."
    
    local app_path="$BUILD_DIR/Payload"/*.app
    local ipa_out="$BUILD_DIR/LeviLauncher-Minecraft.ipa"
    
    # Repack IPA
    cd "$BUILD_DIR/Payload"
    zip -qr "$ipa_out" .
    cd "$SCRIPT_DIR"
    
    if command -v ideviceinstaller &> /dev/null; then
        echo "    Installing via ideviceinstaller..."
        ideviceinstaller -i "$ipa_out"
    elif command -v ios-deploy &> /dev/null; then
        echo "    Installing via ios-deploy..."
        ios-deploy -b "$app_path"
    else
        echo "    IPA ready at: $ipa_out"
        echo "    Install manually with: ideviceinstaller -i \"$ipa_out\""
    fi
    
    echo ""
    echo "=== Injection Complete! ==="
    echo "Launch Minecraft on device - LeviLauncher overlay should appear."
}

# Main
cd "$SCRIPT_DIR"

# Check prerequisites
MISSING=""
command -v xcodebuild >/dev/null 2>&1 || MISSING="$MISSING xcodebuild"
command -v ldid >/dev/null 2>&1 || MISSING="$MISSING ldid"

if [ -n "$MISSING" ]; then
    echo "Missing prerequisites:$MISSING"
    echo ""
    echo "Install them:"
    echo "  xcode-select --install"
    echo "  brew install ldid optool"
    echo "  brew install ideviceinstaller (or use ios-deploy)"
    exit 1
fi

IPA_PATH="${1:-$BUILD_DIR/Minecraft.ipa}"

build_dylib
download_ipa "$IPA_PATH"
inject_dylib
resign
install
