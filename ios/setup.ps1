# LeviLauncher iOS Project Setup Script
# Run this on macOS with Xcode installed

Write-Host "Setting up LeviLauncher iOS project..."

# Check for XcodeGen
$hasXcodeGen = Get-Command xcodegen -ErrorAction SilentlyContinue
if (-not $hasXcodeGen) {
    Write-Host "Installing XcodeGen..."
    brew install xcodegen
}

# Generate Xcode project
Write-Host "Generating Xcode project..."
xcodegen generate --spec project.yml

# Check for CocoaPods
$hasPod = Get-Command pod -ErrorAction SilentlyContinue
if (-not $hasPod) {
    Write-Host "Installing CocoaPods..."
    sudo gem install cocoapods
}

# Install pods if Podfile exists
if (Test-Path "Podfile") {
    Write-Host "Installing Pods..."
    pod install
    Write-Host "Open LeviLauncher.xcworkspace in Xcode"
} else {
    Write-Host "Open LeviLauncher.xcodeproj in Xcode"
}

Write-Host ""
Write-Host "Setup complete!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open the project in Xcode"
Write-Host "  2. Set your Team in Signing & Capabilities"
Write-Host "  3. Set CURSEFORGE_API_KEY in build settings (optional)"
Write-Host "  4. Build and run on iOS 16.0+ device"
Write-Host ""
Write-Host "Note: Mod injection features require a jailbroken device or TrollStore."
Write-Host "The launcher will work as a content manager on stock devices."
