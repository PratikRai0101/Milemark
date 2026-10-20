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
  # Keep the readme light without going soft: the source is 3x, and the
  # images are shown at about a third of a column.
  sips --resampleWidth 900 "$OUT/$name.png" > /dev/null
  echo "  $OUT/$name.png"
}

xcrun simctl ui "$DEVICE" appearance light > /dev/null 2>&1 || true

echo "Capturing:"
capture "01-archive" -seedDemoData
capture "02-receipt-route" -seedDemoData -openReceipt
capture "03-receipt-ascii" -seedDemoData -openReceipt -graphic=ascii
capture "04-receipt-pace" -seedDemoData -openReceipt -graphic=pace
capture "05-share" -seedDemoData -openReceipt -showShare
capture "08-photo" -seedDemoData -openReceipt -graphic=photo -demoPhoto -treatment=poster
capture "06-kept" -seedDemoData -tab=kept

# The live map needs a location to show the route, and the app needs
# permission to receive it. Without both, the capture is a blank world map
# with a zero distance, which is easy to miss.
xcrun simctl privacy "$DEVICE" grant location "$BUNDLE" > /dev/null 2>&1 || true
xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE" -seedDemoData -tab=record -startRecording > /dev/null
sleep 8
for step in 1 2 3 4 5 6; do
  LAT=$(python3 -c "print(1.3050 - $step * 0.00012)")
  LON=$(python3 -c "print(103.8700 + $step * 0.00008)")
  xcrun simctl location "$DEVICE" set "$LAT,$LON" > /dev/null
  sleep 2
done
sleep 3
xcrun simctl io "$DEVICE" screenshot "$OUT/07-tracking.png" > /dev/null 2>&1
sips --resampleWidth 900 "$OUT/07-tracking.png" > /dev/null
echo "  $OUT/07-tracking.png"

# The recorded track is drawn in the signal colour, so a capture with no
# location has none of it. A blank map is a failed capture, not a quiet one.
python3 - "$OUT/07-tracking.png" <<'CHECK'
import sys
from PIL import Image

image = Image.open(sys.argv[1]).convert("RGB")
# The map area of the receipt.
area = image.crop((150, 780, 1060, 1400))
signal = (196, 69, 31)
light_signal = (240, 138, 99)
for red, green, blue in area.getdata():
    if (abs(red - signal[0]) < 45 and abs(green - signal[1]) < 45 and abs(blue - signal[2]) < 45) or (
        abs(red - light_signal[0]) < 45 and abs(green - light_signal[1]) < 45 and abs(blue - light_signal[2]) < 45
    ):
        print("  the track is in the frame")
        break
else:
    print("  no track in the frame: the capture did not record anything", file=sys.stderr)
    raise SystemExit(1)
CHECK

echo "Done."

# The readme lays the images out in a grid, so they have to be the same size.
# A capture that produced a different frame would break the layout.
sizes=$(for file in "$OUT"/*.png; do
  sips -g pixelWidth -g pixelHeight "$file" 2>/dev/null \
    | awk '/pixelWidth|pixelHeight/ { printf "%s ", $2 }'
  echo
done | sort -u)

if [ "$(echo "$sizes" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "Screenshots are not all the same size:" >&2
  echo "$sizes" >&2
  exit 1
fi
echo "All screenshots are $sizes"
