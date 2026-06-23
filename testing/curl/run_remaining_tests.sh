#!/usr/bin/env bash
# Test all remaining INR endpoints using open position
set -euo pipefail
cd "$(dirname "$0")/../.."
SECRET="${MUDREX_API_SECRET:?Set MUDREX_API_SECRET or create .env}"
BASE="https://trade.mudrex.com/fapi/v1"
REPORT="testing/test-report-final.md"

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

{
  echo "# INR Futures API — Final Test Report"
  echo ""
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Environment: Production"
  echo ""
} > "$REPORT"

sleep_between() { sleep 0.7; }

echo "Fetching position..."
POS_RAW=$(api_get '/futures/positions?trade_currency=INR')
POS_JSON=$(echo "$POS_RAW" | sed 's/|HTTP:[0-9]*$//')
POS_ID=$(echo "$POS_JSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
data=d.get('data')
if not data: sys.exit(1)
p=data[0] if isinstance(data,list) else data
print(p['id'])
print(p['entry_price'], file=open('/tmp/entry.txt','w'))
print(p['quantity'], file=open('/tmp/qty.txt','w'))
print(p['liquidation_price'], file=open('/tmp/liq.txt','w'))
" 2>/dev/null || echo "")

if [[ -z "$POS_ID" ]]; then
  echo "No open INR position found" >> "$REPORT"
  echo "No position - aborting remaining tests"
  exit 1
fi

ENTRY=$(cat /tmp/entry.txt)
QTY=$(cat /tmp/qty.txt)
LIQ=$(cat /tmp/liq.txt)
ORDER_ID="019ecc52-2f97-7e34-b3cc-22364e107975"

echo "Position: $POS_ID entry=$ENTRY qty=$QTY liq=$LIQ"

# 1 Position list
log "1. GET open positions (INR)" GET "/futures/positions?trade_currency=INR" "" "$POS_RAW" > /dev/null
sleep_between

# 2 Liq price
R=$(api_get "/futures/positions/${POS_ID}/liq-price?trade_currency=INR")
log "2. GET liquidation price" GET "/futures/positions/${POS_ID}/liq-price?trade_currency=INR" "" "$R" > /dev/null
sleep_between

# 3 Liq price with ext_margin
R=$(api_get "/futures/positions/${POS_ID}/liq-price?trade_currency=INR&ext_margin=1")
log "3. GET liq-price with ext_margin=1" GET "/futures/positions/${POS_ID}/liq-price?trade_currency=INR&ext_margin=1" "" "$R" > /dev/null
sleep_between

# 4 Add margin
R=$(api_post "/futures/positions/${POS_ID}/add-margin" '{"margin":1}')
log "4. POST add-margin (+1 INR)" POST "/futures/positions/${POS_ID}/add-margin" '{"margin":1}' "$R" > /dev/null
sleep_between

# 5 Set SL/TP - SL above liq (0.09293), below entry for LONG
SL="0.10"
TP="0.13"
SLTP_BODY="{\"stoploss_price\":\"${SL}\",\"takeprofit_price\":\"${TP}\",\"order_source\":\"API\",\"is_stoploss\":true,\"is_takeprofit\":true}"
R=$(api_post "/futures/positions/${POS_ID}/riskorder" "$SLTP_BODY")
log "5. POST set SL/TP" POST "/futures/positions/${POS_ID}/riskorder" "$SLTP_BODY" "$R" > /dev/null
sleep_between

# 6 Position after SL/TP
R=$(api_get '/futures/positions?trade_currency=INR')
log "6. GET positions after SL/TP" GET "/futures/positions?trade_currency=INR" "" "$R" > /dev/null
sleep_between

# 7 Open orders (SL/TP)
R=$(api_get '/futures/orders?trade_currency=INR')
ORDERS_JSON=$(echo "$R" | sed 's/|HTTP:[0-9]*$//')
SL_ORDER_ID=$(echo "$ORDERS_JSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for o in d.get('data',[]):
    if o.get('order_type') in ('STOPLOSS','TAKEPROFIT'):
        print(o['id']); break
" 2>/dev/null || echo "")
log "7. GET open orders (INR)" GET "/futures/orders?trade_currency=INR" "" "$R" > /dev/null
sleep_between

# 8 Get order by id (placement order)
R=$(api_get "/futures/orders/${ORDER_ID}")
log "8. GET order by id" GET "/futures/orders/${ORDER_ID}" "" "$R" > /dev/null
sleep_between

# 9 Edit SL/TP
EDIT_BODY='{"stoploss_price":"0.095","takeprofit_price":"0.14","is_stoploss":true,"is_takeprofit":true}'
R=$(api_patch "/futures/positions/${POS_ID}/riskorder" "$EDIT_BODY")
log "9. PATCH edit SL/TP" PATCH "/futures/positions/${POS_ID}/riskorder" "$EDIT_BODY" "$R" > /dev/null
sleep_between

# 10 Partial close 0.1 MARKET
PARTIAL='{"order_type":"MARKET","quantity":"0.1"}'
R=$(api_post "/futures/positions/${POS_ID}/close/partial" "$PARTIAL")
log "10. POST partial close (0.1 MARKET)" POST "/futures/positions/${POS_ID}/close/partial" "$PARTIAL" "$R" > /dev/null
sleep_between

# 11 Position after partial
R=$(api_get '/futures/positions?trade_currency=INR')
log "11. GET positions after partial close" GET "/futures/positions?trade_currency=INR" "" "$R" > /dev/null
sleep_between

# 12 Transfer FUTURES -> SPOT
R=$(api_post '/futures/transfers/inr' '{"amount":"1","from_wallet_type":"FUTURES","to_wallet_type":"SPOT"}')
log "12. POST transfer FUTURES→SPOT (1 INR)" POST "/futures/transfers/inr" '{"amount":"1","from_wallet_type":"FUTURES","to_wallet_type":"SPOT"}' "$R" > /dev/null
sleep_between

# 13 INR spot after reverse transfer
R=$(api_get '/wallet/funds?trade_currency=INR')
log "13. GET INR spot after transfer" GET "/wallet/funds?trade_currency=INR" "" "$R" > /dev/null
sleep_between

# 14 Reduce margin
R=$(api_post "/futures/positions/${POS_ID}/add-margin" '{"margin":-0.5}')
log "14. POST reduce margin (-0.5 INR)" POST "/futures/positions/${POS_ID}/add-margin" '{"margin":-0.5}' "$R" > /dev/null
sleep_between

# 15 Cancel SL order if exists
if [[ -n "$SL_ORDER_ID" ]]; then
  R=$(api_delete "/futures/orders/${SL_ORDER_ID}")
  log "15. DELETE cancel SL order" DELETE "/futures/orders/${SL_ORDER_ID}" "" "$R" > /dev/null
else
  echo "### 15. DELETE cancel order — SKIPPED (no SL order id captured)" >> "$REPORT"
  echo "" >> "$REPORT"
fi
sleep_between

# 16 Reverse position
R=$(api_post "/futures/positions/${POS_ID}/reverse" '{}')
log "16. POST reverse position" POST "/futures/positions/${POS_ID}/reverse" '{}' "$R" > /dev/null
sleep_between

# 17 Position after reverse
R=$(api_get '/futures/positions?trade_currency=INR')
log "17. GET positions after reverse" GET "/futures/positions?trade_currency=INR" "" "$R" > /dev/null
sleep_between

# Get new position id if reversed
NEW_POS_ID=$(echo "$R" | sed 's/|HTTP:[0-9]*$//' | python3 -c "
import sys,json
d=json.load(sys.stdin)
data=d.get('data')
if data and isinstance(data,list) and len(data)>0:
    print(data[0]['id'])
elif data and isinstance(data,dict):
    print(data.get('id',''))
" 2>/dev/null || echo "$POS_ID")
CLOSE_ID="${NEW_POS_ID:-$POS_ID}"

# 18 Square off
R=$(api_post "/futures/positions/${CLOSE_ID}/close" '{}')
log "18. POST square off (close)" POST "/futures/positions/${CLOSE_ID}/close" '{}' "$R" > /dev/null
sleep_between

# 19 Final balances
R=$(api_get '/futures/funds?trade_currency=INR')
log "19. GET final INR futures balance" GET "/futures/funds?trade_currency=INR" "" "$R" > /dev/null
sleep_between

R=$(api_get '/wallet/funds?trade_currency=INR')
log "20. GET final INR spot balance" GET "/wallet/funds?trade_currency=INR" "" "$R" > /dev/null

echo "Report written to $REPORT"
