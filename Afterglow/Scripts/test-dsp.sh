#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_binary="$(mktemp -t afterglow-dsp.XXXXXX)"
trap 'rm -f "$test_binary"' EXIT
cc -std=c11 -Wall -Wextra -Werror -O2 -ICore Core/AGAnalyzer.c Tests/test_dsp.c -lm -pthread -o "$test_binary"
"$test_binary"
