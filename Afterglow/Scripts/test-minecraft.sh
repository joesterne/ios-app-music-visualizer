#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d -t afterglow-minecraft)
trap 'rm -rf "$test_dir"' EXIT
swiftc -module-cache-path "$test_dir/module-cache" \
  Visualizers/MinecraftGeometry.swift Tests/test-minecraft.swift -o "$test_dir/minecraft"
"$test_dir/minecraft"
