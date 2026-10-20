#!/bin/bash
# Captures the screenshots in the readme.
#
# The images are of the real app running in the simulator, not mockups. The
# launch arguments make each screen open where it needs to, so there is no
# tapping involved.
#
# Usage: design/capture-screenshots.sh [device]
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17 Pro}"
BUNDLE="app.milemark.app"
OUT="Screenshots"
DERIVED=".build/screenshots"

if [ ! -d "$DERIVED" ]; then
  xcodebuild build \
    -project Milemark.xcodeproj \
    -scheme Milemark \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO > /dev/null
fi

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Milemark.app"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
sleep 3
xcrun simctl install "$DEVICE" "$APP"

mkdir -p "$OUT"

# capture <name> <arguments...>
capture() {
  local name="$1"
  shift
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE" "$@" > /dev/null
  sleep 7
  xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" > /dev/null 2>&1
  # Keep the readme light: the images are shown at half width.
  sips -Z 620 "$OUT/$name.png" > /dev/null
  echo "  $OUT/$name.png"
}

xcrun simctl ui "$DEVICE" appearance light > /dev/null 2>&1 || true

echo "Capturing:"
capture "01-archive" -seedDemoData
capture "02-receipt-route" -seedDemoData -openReceipt
capture "03-receipt-ascii" -seedDemoData -openReceipt -graphic=ascii
capture "04-receipt-pace" -seedDemoData -openReceipt -graphic=pace
capture "05-share" -seedDemoData -openReceipt -showShare
capture "06-kept" -seedDemoData -tab=kept

# The live map needs a location to show the route.
xcrun simctl location "$DEVICE" set 1.3050,103.8700 > /dev/null 2>&1 || true
xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE" -seedDemoData -tab=record -startRecording > /dev/null
sleep 8
for step in 1 2 3 4 5 6; do
  LAT=$(python3 -c "print(1.3050 - $step * 0.00012)")
  LON=$(python3 -c "print(103.8700 + $step * 0.00008)")
  xcrun simctl location "$DEVICE" set "$LAT,$LON" > /dev/null 2>&1 || true
  sleep 2
done
sleep 3
xcrun simctl io "$DEVICE" screenshot "$OUT/07-tracking.png" > /dev/null 2>&1
sips -Z 620 "$OUT/07-tracking.png" > /dev/null
echo "  $OUT/07-tracking.png"

echo "Done."
