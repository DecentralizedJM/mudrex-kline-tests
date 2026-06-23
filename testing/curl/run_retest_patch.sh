#!/usr/bin/env bash
# Re-test PATCH edit SL/TP and PATCH amend order
set -euo pipefail
cd "$(dirname "$0")/../.."
SECRET="${MUDREX_API_SECRET:?Set MUDREX_API_SECRET or create .env}"
BASE="https://trade.mudrex.com/fapi/v1"
REPORT="testing/test-report-retest.md"

api_get() { curl -sS -w "|HTTP:%{http_code}" -X GET "${BASE}$1" -H "X-Authentication: ${SECRET}"; }
api_post() { curl -sS -w "|HTTP:%{http_code}" -X POST "${BASE}$1" -H "Content-Type: application/json" -H "X-Authentication: ${SECRET}" -d "$2"; }
api_patch() { curl -sS -w "|HTTP:%{http_code}" -X PATCH "${BASE}$1" -H "Content-Type: application/json" -H "X-Authentication: ${SECRET}" -d "$2"; }
api_delete() { curl -sS -w "|HTTP:%{http_code}" -X DELETE "${BASE}$1" -H "X-Authentication: ${SECRET}"; }

log() {
  local name="$1" method="$2" path="$3" body="${4:-}" raw="$5"
  local status body_out
  status=$(echo "$raw" | sed 's/.*|HTTP://')
  body_out=$(echo "$raw" | sed 's/|HTTP:[0-9]*$//')
  {
    echo "### $name"
    echo ""
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Method | \`$method\` |"
    echo "| Path | \`$path\` |"
    echo "| Status | **$status** |"
    [[ -n "$body" ]] && echo "| Request | \`$body\` |"
    echo ""
    echo '```json'
    echo "$body_out" | python3 -m json.tool 2>/dev/null || echo "$body_out"
    echo '```'
    echo ""
  } >> "$REPORT"
  echo "$status"
}

sleep_between() { sleep 0.8; }

{
  echo "# INR API Retest — PATCH edit SL/TP & PATCH amend order"
  echo ""
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo ""
} > "$REPORT"

echo "=== Setup: check balance & asset ==="
FUT=$(api_get '/futures/funds?trade_currency=INR')
log "0. INR futures balance" GET "/futures/funds?trade_currency=INR" "" "$FUT" > /dev/null
BAL=$(echo "$FUT" | sed 's/|HTTP:[0-9]*$//' | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['balance'])")
echo "Balance: $BAL INR"
sleep_between

ASSET=$(api_get '/futures/SOMIUSDT?is_symbol')
PRICE=$(echo "$ASSET" | sed 's/|HTTP:[0-9]*$//' | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['price'])")
QTY=$(echo "$ASSET" | sed 's/|HTTP:[0-9]*$//' | python3 -c "
import sys,json,math
d=json.load(sys.stdin)['data']
price=float(d['price']); mn=float(d['min_notional_value']); step=float(d['quantity_step'])
qty=max(float(d['min_contract']), mn/price)
qty=math.ceil(qty/step)*step
print(f'{qty:.1f}')
")
sleep_between

# Set leverage
api_post '/futures/SOMIUSDT/leverage?is_symbol' '{"margin_type":"ISOLATED","leverage":"5","trade_currency":"INR"}' > /dev/null
sleep_between

echo "=== Step 1: Open INR position ==="
ORDER_BODY="{\"leverage\":\"5\",\"quantity\":\"${QTY}\",\"order_price\":\"${PRICE}\",\"order_type\":\"LONG\",\"trigger_type\":\"MARKET\",\"is_takeprofit\":false,\"is_stoploss\":false,\"reduce_only\":false,\"trade_currency\":\"INR\"}"
R=$(api_post '/futures/SOMIUSDT/order?is_symbol' "$ORDER_BODY")
ORDER_STATUS=$(log "1. Open position (MARKET LONG)" POST "/futures/SOMIUSDT/order?is_symbol" "$ORDER_BODY" "$R")
if [[ "$ORDER_STATUS" != "202" && "$ORDER_STATUS" != "200" ]]; then
  echo "Failed to open position" >> "$REPORT"
  exit 1
fi
sleep_between

POS_RAW=$(api_get '/futures/positions?trade_currency=INR')
POS_ID=$(echo "$POS_RAW" | sed 's/|HTTP:[0-9]*$//' | python3 -c "
import sys,json
d=json.load(sys.stdin)
data=d['data']
p=data[0] if isinstance(data,list) else data
print(p['id'])
print(p['entry_price'], file=open('/tmp/entry.txt','w'))
print(p['liquidation_price'], file=open('/tmp/liq.txt','w'))
")
ENTRY=$(cat /tmp/entry.txt)
LIQ=$(cat /tmp/liq.txt)
echo "Position: $POS_ID entry=$ENTRY liq=$LIQ"
sleep_between

echo "=== Step 2: Set SL/TP ==="
# SL above liq, below entry for LONG
SL_BODY="{\"stoploss_price\":\"0.10\",\"takeprofit_price\":\"0.13\",\"order_source\":\"API\",\"is_stoploss\":true,\"is_takeprofit\":true}"
R=$(api_post "/futures/positions/${POS_ID}/riskorder" "$SL_BODY")
log "2. Set SL/TP" POST "/futures/positions/${POS_ID}/riskorder" "$SL_BODY" "$R" > /dev/null
sleep_between

# Get SL/TP order IDs from position
POS2=$(api_get '/futures/positions?trade_currency=INR')
SL_ID=$(echo "$POS2" | sed 's/|HTTP:[0-9]*$//' | python3 -c "
import sys,json
d=json.load(sys.stdin)
p=d['data'][0]
print(p['stoploss']['order_id'])
")
TP_ID=$(echo "$POS2" | sed 's/|HTTP:[0-9]*$//' | python3 -c "
import sys,json
d=json.load(sys.stdin)
p=d['data'][0]
print(p['takeprofit']['order_id'])
")
echo "SL order: $SL_ID  TP order: $TP_ID"
log "3. GET position (capture order IDs)" GET "/futures/positions?trade_currency=INR" "" "$POS2" > /dev/null
sleep_between

echo "=== Step 3: PATCH edit SL/TP (with order IDs) ==="
EDIT_BODY=$(python3 -c "
import json
print(json.dumps({
    'stoploss_price': '0.095',
    'takeprofit_price': '0.14',
    'stoploss_order_id': '$SL_ID',
    'takeprofit_order_id': '$TP_ID',
    'is_stoploss': True,
    'is_takeprofit': True,
    'trigger_type': 'MARKET'
}))
")
R=$(api_patch "/futures/positions/${POS_ID}/riskorder" "$EDIT_BODY")
PATCH_SL_STATUS=$(log "4. PATCH edit SL/TP (RETEST)" PATCH "/futures/positions/${POS_ID}/riskorder" "$EDIT_BODY" "$R")
sleep_between

R=$(api_get '/futures/positions?trade_currency=INR')
log "5. Verify SL/TP after edit" GET "/futures/positions?trade_currency=INR" "" "$R" > /dev/null
sleep_between

# 7. PATCH amend order (RETEST)

Placed LONG LIMIT order, then amended with `order_price` + `quantity` (both required).

LIMIT_BODY="{\"leverage\":\"5\",\"quantity\":\"44.0\",\"order_price\":\"0.11400\",\"order_type\":\"LONG\",\"trigger_type\":\"LIMIT\",\"is_takeprofit\":false,\"is_stoploss\":false,\"reduce_only\":false,\"trade_currency\":\"INR\"}"
R=$(api_post '/futures/SOMIUSDT/order?is_symbol' "$LIMIT_BODY")
LIMIT_ORDER_ID=$(echo "$R" | sed 's/|HTTP:[0-9]*$//' | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['order_id'])")
log "7. Place LIMIT order (for amend)" POST "/futures/SOMIUSDT/order?is_symbol" "$LIMIT_BODY" "$R" > /dev/null
sleep_between

AMEND_BODY='{"order_price":"0.11380","quantity":"44.0"}'
R=$(api_patch "/futures/orders/${LIMIT_ORDER_ID}" "$AMEND_BODY")
PATCH_AMEND_STATUS=$(log "8. PATCH amend order (RETEST)" PATCH "/futures/orders/${LIMIT_ORDER_ID}" "$AMEND_BODY" "$R")
sleep_between

R=$(api_get "/futures/orders/${LIMIT_ORDER_ID}")
log "9. Verify amended order" GET "/futures/orders/${LIMIT_ORDER_ID}" "" "$R" > /dev/null
sleep_between

R=$(api_delete "/futures/orders/${LIMIT_ORDER_ID}")
log "10. Cancel LIMIT order (cleanup)" DELETE "/futures/orders/${LIMIT_ORDER_ID}" "" "$R" > /dev/null
sleep_between

echo "=== Cleanup: close position ==="
R=$(api_post "/futures/positions/${POS_ID}/close" '{}')
log "10. Close position (cleanup)" POST "/futures/positions/${POS_ID}/close" '{}' "$R" > /dev/null
sleep_between

R=$(api_get '/futures/funds?trade_currency=INR')
log "11. Final INR futures balance" GET "/futures/funds?trade_currency=INR" "" "$R" > /dev/null

echo ""
echo "PATCH edit SL/TP: $PATCH_SL_STATUS"
echo "PATCH amend order: ${PATCH_AMEND_STATUS:-N/A}"
echo "Report: $REPORT"
