#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d -t afterglow-tron)"
trap 'rm -rf "$test_dir"' EXIT
sdk_options=()
if [[ -n "${AFTERGLOW_TEST_SDK:-}" ]]; then sdk_options=(-sdk "$AFTERGLOW_TEST_SDK"); fi
swiftc "${sdk_options[@]}" -module-cache-path "$test_dir/module-cache" \
    App/Models.swift Visualizers/TronSettings.swift Visualizers/TronGeometry.swift \
    Tests/test_tron.swift -o "$test_dir/test-tron"
"$test_dir/test-tron"
