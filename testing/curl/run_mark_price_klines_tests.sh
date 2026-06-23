#!/usr/bin/env bash
# Mark price & LTP klines REST tests.
# Update KLINES_PATH and query param names when engineering confirms contract.
set -euo pipefail

cd "$(dirname "$0")/../.."
# shellcheck disable=SC1091
source testing/curl/common.sh

SYMBOL="${MUDREX_TEST_SYMBOL:-BTCUSDT}"
INTERVAL="${MUDREX_KLINE_INTERVAL:-1m}"
LIMIT="${MUDREX_KLINE_LIMIT:-10}"
REPORT="${MUDREX_KLINES_REPORT:-testing/mark-price-klines-test-results.md}"

# --- Contract config (edit when engineer confirms) ---
KLINES_PATH="/futures/${SYMBOL}/klines?is_symbol"
PRICE_TYPE_PARAM="price_type"   # e.g. price_type=mark | ltp
MARK_VALUE="mark"
LTP_VALUE="ltp"

mkdir -p "$(dirname "$REPORT")"
: > "$REPORT"

log_section() {
  local title="$1"
  local method="$2"
  local path="$3"
  local body="$4"
  local raw="$5"
  local http
  http=$(printf '%s' "$raw" | sed -n 's/.*__HTTP_STATUS__:\([0-9]*\)$/\1/p')
  local json
  json=$(printf '%s' "$raw" | sed 's/__HTTP_STATUS__:[0-9]*$//')

  {
    echo "## ${title}"
    echo ""
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Method | \`${method}\` |"
    echo "| Path | \`${path}\` |"
    echo "| HTTP | **${http:-unknown}** |"
    echo ""
    if [[ -n "$body" ]]; then
      echo "**Query / params:** \`${body}\`"
      echo ""
    fi
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

run_klines() {
  local label="$1"
  local price_type="$2"
  local extra=""
  if [[ -n "$price_type" ]]; then
    extra="&${PRICE_TYPE_PARAM}=${price_type}"
  fi
  local path="${KLINES_PATH}&interval=${INTERVAL}&limit=${LIMIT}${extra}"
  local raw
  raw=$(api_get "$path")
  log_section "$label" "GET" "$path" "interval=${INTERVAL}, limit=${LIMIT}${extra}" "$raw"
  printf '%s' "$raw" | sed 's/__HTTP_STATUS__:[0-9]*$//'
}

probe_path() {
  local label="$1"
  local path="$2"
  local raw
  raw=$(api_get "$path")
  log_section "$label" "GET" "$path" "" "$raw"
}

{
  echo "# Mark Price & LTP Klines — Test Results"
  echo ""
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Base URL: ${BASE_URL}"
  echo "Symbol: ${SYMBOL}"
  echo ""
  echo "> Update \`KLINES_PATH\` and \`${PRICE_TYPE_PARAM}\` in \`run_mark_price_klines_tests.sh\` if the contract differs."
  echo ""
} >> "$REPORT"

echo "Running klines tests → ${REPORT}"

probe_path "0. Endpoint exists (base klines path)" "${KLINES_PATH}&interval=${INTERVAL}&limit=3"

MARK_JSON=$(run_klines "1. Mark price klines" "$MARK_VALUE" || true)
sleep 0.5
LTP_JSON=$(run_klines "2. LTP klines" "$LTP_VALUE" || true)
sleep 0.5
run_klines "3. Invalid price type" "invalid_type_xyz" || true
sleep 0.5
probe_path "4. Invalid interval" "${KLINES_PATH}&interval=99x&limit=3&${PRICE_TYPE_PARAM}=${MARK_VALUE}" || true
sleep 0.5
probe_path "5. Invalid symbol" "/futures/NOTASymbol/klines?is_symbol&interval=${INTERVAL}&limit=3&${PRICE_TYPE_PARAM}=${MARK_VALUE}" || true

# Simple comparison if both returned JSON
if command -v python3 >/dev/null 2>&1; then
  MARK_JSON="$MARK_JSON" LTP_JSON="$LTP_JSON" python3 - <<'PY' >> "$REPORT" 2>&1 || true
import json, os

def load_raw(s):
    s = (s or "").strip()
    if not s:
        return None
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        return None

mark = load_raw(os.environ.get("MARK_JSON"))
ltp = load_raw(os.environ.get("LTP_JSON"))

print("## 6. Mark vs LTP comparison")
print("")
if mark is None or ltp is None:
    print("_Skipped — one or both responses were not valid JSON (endpoint may not be live yet)._")
else:
    print(f"- Mark response type: `{type(mark).__name__}`")
    print(f"- LTP response type: `{type(ltp).__name__}`")
    if mark == ltp:
        print("- **Warning:** Mark and LTP responses are identical — verify price_type filter works.")
    else:
        print("- Mark and LTP responses differ (expected).")
print("")
PY
fi

echo "Done. See ${REPORT}"
