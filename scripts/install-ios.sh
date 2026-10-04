#!/bin/sh
# Release build onto the first paired physical iPhone.
# Usage: scripts/install-ios.sh [device-udid]
set -e
cd "$(dirname "$0")/.."

DEVICE=${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/available \(paired\)/ && /physical/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) print $i; exit}')}
[ -n "$DEVICE" ] || { echo "No paired iPhone found. Connect one, unlock it, then retry."; exit 1; }

xcodegen generate
xcodebuild -project PhotoEditor.xcodeproj -scheme PhotoEditor -configuration Release \
  -destination "id=$DEVICE" -derivedDataPath build/release -allowProvisioningUpdates build
xcrun devicectl device install app --device "$DEVICE" build/release/Build/Products/Release-iphoneos/PhotoEditor.app
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing "$(sed -n 's/^APP_NAMESPACE *= *//p' Config/Local.xcconfig).app"
