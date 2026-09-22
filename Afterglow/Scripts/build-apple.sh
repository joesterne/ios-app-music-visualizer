#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
  echo 'Xcode is required. Run this script on a Mac with Xcode selected in Settings > Locations.' >&2
  exit 1
fi
bash Scripts/test-dsp.sh
xcodebuild -project Afterglow.xcodeproj -scheme Afterglow-Mac -configuration Debug \
  -destination 'generic/platform=macOS' -derivedDataPath .build/Mac \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Afterglow.xcodeproj -scheme Afterglow-iOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/iOS \
  CODE_SIGNING_ALLOWED=NO build
