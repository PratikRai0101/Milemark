#!/bin/bash
# Record a continuous native showcase. Python handles cue-based trimming,
# recorder shutdown on failure, and validation before publishing either asset.
# Usage: bash design/record-demo.sh [device]
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 design/record-demo.py "$@"
