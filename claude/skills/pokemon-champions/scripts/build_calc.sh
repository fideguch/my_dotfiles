#!/usr/bin/env bash
# Phase 2: Build the calc_wrapper binary.
# Output: ../bin/pokechamp-calc
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p ../bin
bun build --compile calc_wrapper.ts --outfile ../bin/pokechamp-calc
ls -lh ../bin/pokechamp-calc
echo "Build OK"
