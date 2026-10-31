#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d -t afterglow-audio-response)"
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -c Core/AGAnalyzer.c -o "$test_dir/AudioDSP.o"
xcrun swiftc -parse-as-library -module-cache-path "$test_dir/module-cache" \
  -import-objc-header Config/Afterglow-Bridging-Header.h -I Core \
  App/Models.swift Visualizers/TronSettings.swift Visualizers/VisualizerClock.swift Services/PreferenceStore.swift \
  Audio/AudioAnalyzer.swift App/StudioModel.swift Tests/test-audio-response.swift \
  "$test_dir/AudioDSP.o" -o "$test_dir/test-audio-response"
"$test_dir/test-audio-response"
