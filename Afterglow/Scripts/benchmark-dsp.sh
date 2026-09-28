#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
benchmark_binary="$(mktemp -t afterglow-benchmark.XXXXXX)"
trap 'rm -f "$benchmark_binary"' EXIT
# Optionally pass a previous AGAnalyzer.c for an identical before/after workload.
cc -std=c11 -Wall -Wextra -Werror -O2 -ICore "${1:-Core/AGAnalyzer.c}" Tests/benchmark_dsp.c -lm -pthread -o "$benchmark_binary"
"$benchmark_binary"
