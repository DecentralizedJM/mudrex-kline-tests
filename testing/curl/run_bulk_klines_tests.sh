#!/usr/bin/env bash
# Bulk LTP & Mark Price klines — Data Read Client REST tests
# Contract: docs/data-read-client-dev-context.md
set -euo pipefail

cd "$(dirname "$0")/../.."

PRICE_BASE="${MUDREX_PRICE_BASE_URL:-https://price.mudrex.com/api/v1}"
ASSET="${MUDREX_TEST_ASSET:-btc/usdt}"
AGG="${MUDREX_KLINE_AGGREGATION:-1m}"
# Default window from dev sample (adjust when testing live)
START_TIME="${MUDREX_KLINE_START:-1781172000}"
END_TIME="${MUDREX_KLINE_END:-1781172300}"
TYPE="${MUDREX_ASSET_TYPE:-linear}"
REPORT="${MUDREX_BULK_KLINES_REPORT:-testing/bulk-klines-test-results.md}"

# Internal params (may not be in external docs — dev confirmed for testing)
EXTRA_PARAMS="ohlcv=true&partial=true&type=${TYPE}"

mkdir -p "$(dirname "$REPORT")"
: > "$REPORT"

price_get() {
  local path="$1"
  /usr/bin/curl -sS -w "\n__HTTP_STATUS__:%{http_code}" \
    -X GET "${PRICE_BASE}${path}"
}

log_section() {
  local title="$1"
  local url="$2"
  local raw="$3"
  local http
  http=$(printf '%s' "$raw" | sed -n 's/.*__HTTP_STATUS__:\([0-9]*\)$/\1/p')
  local json
  json=$(printf '%s' "$raw" | sed 's/__HTTP_STATUS__:[0-9]*$//')

  {
    echo "## ${title}"
    echo ""
    echo "**URL:** \`${url}\`"
    echo ""
    echo "**HTTP:** ${http:-unknown}"
    echo ""
    echo '```json'
    if command -v python3 >/dev/null 2>&1; then
      printf '%s' "$json" | python3 -m json.tool 2>/dev/null || printf '%s' "$json"
    else
      printf '%s' "$json"
    fi
    echo ""
    echo '```'
    echo ""
    echo "---"
    echo ""
  } >> "$REPORT"
}

LTP_PATH="/assets/price?assets=${ASSET}&aggregation=${AGG}&start_time=${START_TIME}&end_time=${END_TIME}&${EXTRA_PARAMS}"
MARK_PATH="/assets/mark-price?assets=${ASSET}&aggregation=${AGG}&start_time=${START_TIME}&end_time=${END_TIME}&${EXTRA_PARAMS}"

{
  echo "# Bulk Klines — Test Results"
  echo ""
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Base: ${PRICE_BASE}"
  echo "Asset: ${ASSET}"
  echo ""
  echo "> External-facing params (per PM): \`assets\`, \`aggregation\`, \`start_time\`, \`end_time\` only."
  echo ""
} >> "$REPORT"

echo "Testing bulk klines → ${REPORT}"

LTP_RAW=$(price_get "$LTP_PATH")
log_section "1. Bulk LTP klines — GET /assets/price" "${PRICE_BASE}${LTP_PATH}" "$LTP_RAW"
sleep 0.5

MARK_RAW=$(price_get "$MARK_PATH")
log_section "2. Bulk Mark klines — GET /assets/mark-price" "${PRICE_BASE}${MARK_PATH}" "$MARK_RAW"

# Validate candle field counts if JSON parses
if command -v python3 >/dev/null 2>&1; then
  LTP_RAW="$LTP_RAW" MARK_RAW="$MARK_RAW" python3 - <<'PY' >> "$REPORT" 2>&1 || true
import json, os

def parse(raw):
    raw = (raw or "").split("__HTTP_STATUS__:")[0].strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None

def check_candles(label, data, expected_len):
    print(f"### Validation — {label}")
    print("")
    if not data or not data.get("success"):
        print("_No success response — endpoint may not be live yet._")
        print("")
        return
    ticks = (data.get("data") or {}).get("asset_ticks") or {}
    for asset, candles in ticks.items():
        if not candles:
            print(f"- `{asset}`: empty")
            continue
        lens = {len(c) for c in candles}
        print(f"- `{asset}`: {len(candles)} candles, field counts {lens} (expected {expected_len})")
    print("")

ltp = parse(os.environ.get("LTP_RAW"))
mark = parse(os.environ.get("MARK_RAW"))
check_candles("LTP (6 fields: t,o,h,l,c,v)", ltp, 6)
check_candles("Mark (5 fields: t,o,h,l,c)", mark, 5)
PY
fi

echo "Done. See ${REPORT}"
