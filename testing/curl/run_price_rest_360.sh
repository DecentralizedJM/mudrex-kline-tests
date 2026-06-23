#!/usr/bin/env bash
# Wrapper for REST 360 tests
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 testing/price_rest_360.py "$@"
