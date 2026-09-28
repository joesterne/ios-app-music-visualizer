#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
render_directory=$(mktemp -d)
trap 'rm -rf "$render_directory"' EXIT
node --check Web/app.js
node Tests/test-controls.cjs
node Tests/test_preview.cjs
node Tests/test-preview.cjs
node Tests/test-duo-demo.cjs
node Tests/test-yosemite-rendering.cjs "$render_directory"
bash Scripts/test-dsp.sh
