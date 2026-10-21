#!/bin/bash
# Records the demo in the readme.
#
# The app is driven by a UI test while the simulator's screen is recorded, so
# the video is of the real app doing the real thing: open a run, watch the
# receipt feed out of the tray, pull the paper off.
#
# Usage: bash design/record-demo.sh [device]
set -uo pipefail

cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17e}"
DERIVED=".build/demo"
MOV="design/demo/milemark-demo.mp4"
GIF="design/demo/milemark-demo.gif"

mkdir -p design/demo

xcodebuild build \
  -project Milemark.xcodeproj \
  -scheme Milemark \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" > /dev/null

xcrun simctl install "$DEVICE" "$DERIVED/Build/Products/Debug-iphonesimulator/Milemark.app"

# A recording that was killed leaves the device thinking one is still running,
# so it is rebooted first.
xcrun simctl shutdown "$DEVICE" 2>/dev/null
sleep 4
xcrun simctl boot "$DEVICE" 2>/dev/null
sleep 22
xcrun simctl install "$DEVICE" "$DERIVED/Build/Products/Debug-iphonesimulator/Milemark.app"
sleep 2

rm -f "$MOV"
xcrun simctl io "$DEVICE" recordVideo --codec=h264 --force "$MOV" > /dev/null 2>&1 &
RECORDER=$!
sleep 6

xcodebuild test \
  -project Milemark.xcodeproj \
  -scheme Milemark \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  -only-testing:MilemarkUITests/CoreLoopTests/testTheCoreLoop 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED" | tail -1

sleep 3
# The recorder needs an interrupt, not a kill, to write the file out.
kill -INT "$RECORDER" 2>/dev/null
wait "$RECORDER" 2>/dev/null
sleep 3

if [ ! -f "$MOV" ]; then
  echo "No recording was made. Is the device busy recording something else?" >&2
  exit 1
fi

# The app is torn down when the test ends, so the tail of the video is the
# home screen and is cut off.
ffmpeg -y -v error -ss 10 -to 49 -i "$MOV" -c:v libx264 -pix_fmt yuv420p -crf 30 \
  -vf "scale=390:-2" -movflags +faststart -an "$MOV"

ffmpeg -y -v error -ss 10 -to 49 -i "$MOV" -vf \
  "fps=12,scale=320:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 "$GIF"

ls -la "$MOV" "$GIF"
