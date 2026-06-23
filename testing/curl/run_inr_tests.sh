#!/usr/bin/env bash
# Comprehensive INR endpoint tests — every endpoint that supports trade_currency=INR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

source testing/curl/common.sh

RESULTS_FILE="testing/test-results-inr.md"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p testing

{
  echo "# INR Endpoint Test Results (Full Sweep)"
  echo ""
  echo "Generated: ${TIMESTAMP}"
  echo "Base URL: ${BASE_URL}"
  echo ""
} > "${RESULTS_FILE}"

log_test() {
  local name="$1"
  local method="$2"
  local path="$3"
  local body="${4:-}"
  local raw="$5"

  local status
  status=$(echo "${raw}" | sed -n 's/.*__HTTP_STATUS__:\([0-9]*\).*/\1/p' | tail -1)
  local response
  response=$(echo "${raw}" | sed 's/__HTTP_STATUS__:[0-9]*$//')

  {
    echo "## ${name}"
    echo ""
    echo "**${method}** \`${path}\`"
    echo ""
    echo "**Status:** ${status}"
    echo ""
    if [[ -n "${body}" ]]; then
      echo "**Request body:**"
      echo '```json'
      echo "${body}" | python3 -m json.tool 2>/dev/null || echo "${body}"
      echo '```'
      echo ""
    fi
    echo "**Response:**"
    echo '```json'
    echo "${response}" | python3 -m json.tool 2>/dev/null || echo "${response}"
    echo '```'
    echo ""
    echo "---"
    echo ""
  } >> "${RESULTS_FILE}"
}

sleep_between() { sleep 0.6; }

echo "=== Phase 1: INR Balances ==="

log_test "1. INR Spot Wallet" GET "/wallet/funds?trade_currency=INR" "" "$(api_get '/wallet/funds?trade_currency=INR')"
sleep_between

log_test "2. INR Futures Wallet" GET "/futures/funds?trade_currency=INR" "" "$(api_get '/futures/funds?trade_currency=INR')"
sleep_between

echo "=== Phase 2: INR Transfer (Spot → Futures) ==="

# Read spot withdrawable to decide transfer amount
SPOT_RAW=$(api_get '/wallet/funds?trade_currency=INR')
SPOT_WITHDRAWABLE=$(echo "${SPOT_RAW}" | sed 's/__HTTP_STATUS__:[0-9]*$//' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'].get('withdrawable', 0))" 2>/dev/null || echo "0")
sleep_between

if python3 -c "import sys; exit(0 if float('${SPOT_WITHDRAWABLE}') >= 1 else 1)" 2>/dev/null; then
  TRANSFER_AMT="1"
else
  TRANSFER_AMT="0.01"
fi

TRANSFER_BODY=$(cat <<EOF
{
  "amount": "${TRANSFER_AMT}",
  "from_wallet_type": "SPOT",
  "to_wallet_type": "FUTURES"
}
EOF
)
log_test "3. INR Transfer SPOT → FUTURES" POST "/futures/transfers/inr" "${TRANSFER_BODY}" "$(api_post '/futures/transfers/inr' "${TRANSFER_BODY}")"
sleep_between

log_test "4. INR Spot Wallet (after transfer)" GET "/wallet/funds?trade_currency=INR" "" "$(api_get '/wallet/funds?trade_currency=INR')"
sleep_between

log_test "5. INR Futures Wallet (after transfer)" GET "/futures/funds?trade_currency=INR" "" "$(api_get '/futures/funds?trade_currency=INR')"
sleep_between

echo "=== Phase 3: INR Transactions ==="

log_test "6. INR Transactions (all)" GET "/futures/transactions?limit=10&trade_currency=INR" "" "$(api_get '/futures/transactions?limit=10&trade_currency=INR')"
sleep_between

log_test "7. INR Transactions (DEPOSIT)" GET "/futures/transactions?limit=5&type=DEPOSIT&trade_currency=INR" "" "$(api_get '/futures/transactions?limit=5&type=DEPOSIT&trade_currency=INR')"
sleep_between

log_test "8. INR Transactions (WITHDRAW)" GET "/futures/transactions?limit=5&type=WITHDRAW&trade_currency=INR" "" "$(api_get '/futures/transactions?limit=5&type=WITHDRAW&trade_currency=INR')"
sleep_between

echo "=== Phase 4: Leverage (INR) ==="

log_test "9. Get BTCUSDT Leverage (INR)" GET "/futures/BTCUSDT/leverage?is_symbol&trade_currency=INR" "" "$(api_get '/futures/BTCUSDT/leverage?is_symbol&trade_currency=INR')"
sleep_between

SET_LEV='{"margin_type":"ISOLATED","leverage":"2","trade_currency":"INR"}'
log_test "10. Set BTCUSDT Leverage (INR)" POST "/futures/BTCUSDT/leverage?is_symbol" "${SET_LEV}" "$(api_post '/futures/BTCUSDT/leverage?is_symbol' "${SET_LEV}")"
sleep_between

log_test "11. Get ETHUSDT Leverage (INR)" GET "/futures/ETHUSDT/leverage?is_symbol&trade_currency=INR" "" "$(api_get '/futures/ETHUSDT/leverage?is_symbol&trade_currency=INR')"
sleep_between

echo "=== Phase 5: Orders (INR) ==="

log_test "12. INR Open Orders" GET "/futures/orders?limit=10&trade_currency=INR" "" "$(api_get '/futures/orders?limit=10&trade_currency=INR')"
sleep_between

log_test "13. INR Order History" GET "/futures/orders/history?limit=5&trade_currency=INR" "" "$(api_get '/futures/orders/history?limit=5&trade_currency=INR')"
sleep_between

# Get a cheap asset for order test
CHEAP_RAW=$(api_get '/futures?limit=50&sort=popularity')
CHEAP=$(echo "${CHEAP_RAW}" | sed 's/__HTTP_STATUS__:[0-9]*$//' | python3 -c "
import sys, json
d = json.load(sys.stdin)
# pick asset with low min_notional and low price
best = sorted(d['data'], key=lambda x: float(x.get('min_notional_value', 999)))[0]
print(best['symbol'] + '|' + best['price'] + '|' + best['min_contract'] + '|' + best['min_leverage'])
" 2>/dev/null || echo "DOGEUSDT|0.2|1|1")
SYMBOL=$(echo "$CHEAP" | cut -d'|' -f1)
PRICE=$(echo "$CHEAP" | cut -d'|' -f2)
MIN_QTY=$(echo "$CHEAP" | cut -d'|' -f3)
MIN_LEV=$(echo "$CHEAP" | cut -d'|' -f4)
sleep_between

ORDER_BODY=$(cat <<EOF
{
  "leverage": "${MIN_LEV}",
  "quantity": "${MIN_QTY}",
  "order_price": "${PRICE}",
  "order_type": "LONG",
  "trigger_type": "MARKET",
  "is_takeprofit": false,
  "is_stoploss": false,
  "reduce_only": false,
  "trade_currency": "INR"
}
EOF
)
log_test "14. Place INR Order (${SYMBOL})" POST "/futures/${SYMBOL}/order?is_symbol" "${ORDER_BODY}" "$(api_post "/futures/${SYMBOL}/order?is_symbol" "${ORDER_BODY}")"
sleep_between

echo "=== Phase 6: Positions (INR) ==="

log_test "15. INR Open Positions" GET "/futures/positions?limit=10&trade_currency=INR" "" "$(api_get '/futures/positions?limit=10&trade_currency=INR')"
sleep_between

log_test "16. INR Position History" GET "/futures/positions/history?limit=5&trade_currency=INR" "" "$(api_get '/futures/positions/history?limit=5&trade_currency=INR')"
sleep_between

# If we have an open INR position, test liq-price
POS_RAW=$(api_get '/futures/positions?limit=1&trade_currency=INR')
POS_ID=$(echo "${POS_RAW}" | sed 's/__HTTP_STATUS__:[0-9]*$//' | python3 -c "
import sys, json
d = json.load(sys.stdin)
data = d.get('data')
if data and isinstance(data, list) and len(data) > 0:
    print(data[0]['id'])
elif data and isinstance(data, dict):
    print(data.get('id',''))
" 2>/dev/null || echo "")
sleep_between

if [[ -n "${POS_ID}" ]]; then
  log_test "17. INR Position Liq Price" GET "/futures/positions/${POS_ID}/liq-price?trade_currency=INR" "" "$(api_get "/futures/positions/${POS_ID}/liq-price?trade_currency=INR")"
  sleep_between
else
  echo "## 17. INR Position Liq Price — SKIPPED (no open INR position)" >> "${RESULTS_FILE}"
  echo "" >> "${RESULTS_FILE}"
fi

echo "=== Phase 7: Fees (INR) ==="

log_test "18. INR Fee History" GET "/futures/fee/history?limit=5&trade_currency=INR" "" "$(api_get '/futures/fee/history?limit=5&trade_currency=INR')"
sleep_between

echo "=== Phase 8: Asset listing (unchanged, no trade_currency) ==="

log_test "19. Asset Listing (no currency param)" GET "/futures?limit=3" "" "$(api_get '/futures?limit=3')"
sleep_between

log_test "20. Asset Detail BTCUSDT (no currency param)" GET "/futures/BTCUSDT?is_symbol" "" "$(api_get '/futures/BTCUSDT?is_symbol')"
sleep_between

echo "=== Phase 9: Error cases ==="

log_test "21. Invalid trade_currency (EUR)" GET "/futures/funds?trade_currency=EUR" "" "$(api_get '/futures/funds?trade_currency=EUR')"

echo "Done. Results: ${RESULTS_FILE}"
