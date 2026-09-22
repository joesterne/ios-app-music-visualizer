#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d -t afterglow-tron)"
trap 'rm -rf "$test_dir"' EXIT
set -- -module-cache-path "$test_dir/module-cache"
if [[ -n "${AFTERGLOW_TEST_SDK:-}" ]]; then set -- -sdk "$AFTERGLOW_TEST_SDK" "$@"; fi
swiftc "$@" \
    App/Models.swift Visualizers/TronSettings.swift Visualizers/TronGeometry.swift \
    Tests/test_tron.swift -o "$test_dir/test-tron"
"$test_dir/test-tron"
