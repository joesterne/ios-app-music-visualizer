#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
  echo 'Xcode is required. Run this script on a Mac with Xcode selected in Settings > Locations.' >&2
  exit 1
fi
sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version)
sdk_major=${sdk_version%%.*}
sdk_remainder=${sdk_version#*.}
sdk_minor=${sdk_remainder%%.*}
if (( sdk_major < 27 || (sdk_major == 27 && sdk_minor < 1) )); then
  echo 'The Duo iOS workspace requires the iOS 27.1 SDK. Select Xcode 27.1 or newer in Xcode > Settings > Locations.' >&2
  exit 1
fi
bash Scripts/test-dsp.sh
bash Scripts/test-tron.sh
bash Scripts/test-forest.sh
test_directory=$(mktemp -d)
trap 'rm -rf "$test_directory"' EXIT
xcrun swiftc -parse-as-library App/Models.swift Visualizers/TronSettings.swift Visualizers/VisualizerClock.swift \
  Services/PreferenceStore.swift Tests/test-native-preferences.swift -o "$test_directory/preferences-test"
"$test_directory/preferences-test"
xcodebuild -project Afterglow.xcodeproj -scheme Afterglow-Mac -configuration Debug \
  -destination 'generic/platform=macOS' -derivedDataPath .build/Mac \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Afterglow.xcodeproj -scheme Afterglow-iOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/iOS \
  CODE_SIGNING_ALLOWED=NO build
