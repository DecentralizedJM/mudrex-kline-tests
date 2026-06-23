#!/usr/bin/env bash
# Top-level 360° price API test runner
set -uo pipefail
cd "$(dirname "$0")/.."

# Trade API key — required for C8 cross-check and ASSETS=all symbol refresh (optional for price-only)
if [[ -z "${MUDREX_API_SECRET:-}" && -f .env ]]; then
  set -a; source .env; set +a
fi
export MUDREX_PRICE_BASE_URL="${MUDREX_PRICE_BASE_URL:-https://price.mudrex.com/api/v1}"

echo "=== Price API 360° Test Suite ==="
echo "Base: ${MUDREX_PRICE_BASE_URL}"
echo ""

pip3 install -q -r testing/ws/requirements.txt 2>/dev/null || true

echo "--- Phase 1: REST 360 ---"
python3 testing/price_rest_360.py || REST_EXIT=$?
REST_EXIT=${REST_EXIT:-0}

echo ""
echo "--- Phase 2: WebSocket 360 ---"
python3 testing/price_ws_360.py || WS_EXIT=$?
WS_EXIT=${WS_EXIT:-0}

echo ""
echo "--- Phase 3: Generate report ---"
python3 testing/generate_360_report.py

echo ""
echo "Done. Report: Mark_Price_LTP_360_Test_Report.md"
exit $(( REST_EXIT + WS_EXIT ))
