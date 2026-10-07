#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d -t afterglow-forest)
trap 'rm -rf "$test_dir"' EXIT
swiftc -module-cache-path "$test_dir/module-cache" \
  Visualizers/ForestWalkGeometry.swift Tests/test-forest.swift -o "$test_dir/forest"
"$test_dir/forest"
