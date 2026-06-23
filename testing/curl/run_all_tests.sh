#!/usr/bin/env bash
# Run all INR Futures API tests and write results to testing/test-results.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck source=testing/curl/common.sh
source testing/curl/common.sh

RESULTS_FILE="testing/test-results.md"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p testing

{
  echo "# INR Futures API Test Results"
  echo ""
  echo "Generated: ${TIMESTAMP}"
  echo "Base URL: ${BASE_URL}"
  echo ""
} > "${RESULTS_FILE}"

log_test() {
  local name="$1"
  local method="$2"
  local path="$3"
  local body="$4"
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
    echo '```json'
    echo "${response}" | python3 -m json.tool 2>/dev/null || echo "${response}"
    echo '```'
    echo ""
    if [[ -n "${body}" ]]; then
      echo "**Request body:**"
      echo '```json'
      echo "${body}" | python3 -m json.tool 2>/dev/null || echo "${body}"
      echo '```'
      echo ""
    fi
    echo "---"
    echo ""
  } >> "${RESULTS_FILE}"
}

echo "Running API tests..."

# Phase 0: Backward compat (USDT default)
log_test "USDT spot funds (no trade_currency)" GET "/wallet/funds" "" "$(api_get '/wallet/funds')"
sleep 0.6
log_test "USDT futures funds (no trade_currency)" GET "/futures/funds" "" "$(api_get '/futures/funds')"
sleep 0.6
log_test "Asset listing (unchanged)" GET "/futures?limit=3" "" "$(api_get '/futures?limit=3')"
sleep 0.6
log_test "USDT open positions (no trade_currency)" GET "/futures/positions?limit=5" "" "$(api_get '/futures/positions?limit=5')"
sleep 0.6
log_test "USDT open orders (no trade_currency)" GET "/futures/orders?limit=5" "" "$(api_get '/futures/orders?limit=5')"
sleep 0.6

# Phase 1: Read-only INR
log_test "INR spot funds" GET "/wallet/funds?trade_currency=INR" "" "$(api_get '/wallet/funds?trade_currency=INR')"
sleep 0.6
log_test "INR futures funds" GET "/futures/funds?trade_currency=INR" "" "$(api_get '/futures/funds?trade_currency=INR')"
sleep 0.6
log_test "INR transactions" GET "/futures/transactions?limit=20&trade_currency=INR" "" "$(api_get '/futures/transactions?limit=20&trade_currency=INR')"
sleep 0.6
log_test "INR fee history" GET "/futures/fee/history?limit=5&trade_currency=INR" "" "$(api_get '/futures/fee/history?limit=5&trade_currency=INR')"
sleep 0.6
log_test "Invalid trade_currency (EUR)" GET "/futures/funds?trade_currency=EUR" "" "$(api_get '/futures/funds?trade_currency=EUR')"
sleep 0.6

# Phase 2: Transfers
INR_TRANSFER_BODY='{"amount":"1","from_wallet_type":"SPOT","to_wallet_type":"FUTURES"}'
log_test "INR transfer (engineer path)" POST "/futures/transfers/inr" "${INR_TRANSFER_BODY}" "$(api_post '/futures/transfers/inr' "${INR_TRANSFER_BODY}")"
sleep 0.6

USDT_TRANSFER_BODY='{"amount":"1","from_wallet_type":"SPOT","to_wallet_type":"FUTURES","trade_currency":"INR"}'
log_test "INR transfer (USDT path + trade_currency)" POST "/wallet/futures/transfer" "${USDT_TRANSFER_BODY}" "$(api_post '/wallet/futures/transfer' "${USDT_TRANSFER_BODY}")"
sleep 0.6

# Phase 3: Leverage
log_test "BTCUSDT leverage USDT" GET "/futures/BTCUSDT/leverage?is_symbol" "" "$(api_get '/futures/BTCUSDT/leverage?is_symbol&trade_currency=USDT')"
sleep 0.6
log_test "BTCUSDT leverage INR" GET "/futures/BTCUSDT/leverage?is_symbol" "" "$(api_get '/futures/BTCUSDT/leverage?is_symbol&trade_currency=INR')"
sleep 0.6

SET_LEVERAGE_INR='{"margin_type":"ISOLATED","leverage":"2","trade_currency":"INR"}'
log_test "Set BTCUSDT leverage INR" POST "/futures/BTCUSDT/leverage?is_symbol" "${SET_LEVERAGE_INR}" "$(api_post '/futures/BTCUSDT/leverage?is_symbol' "${SET_LEVERAGE_INR}")"
sleep 0.6

SET_LEVERAGE_USDT='{"margin_type":"ISOLATED","leverage":"1.5","trade_currency":"USDT"}'
log_test "Set BTCUSDT leverage USDT" POST "/futures/BTCUSDT/leverage?is_symbol" "${SET_LEVERAGE_USDT}" "$(api_post '/futures/BTCUSDT/leverage?is_symbol' "${SET_LEVERAGE_USDT}")"
sleep 0.6

log_test "Verify INR leverage after set" GET "/futures/BTCUSDT/leverage?is_symbol" "" "$(api_get '/futures/BTCUSDT/leverage?is_symbol&trade_currency=INR')"
sleep 0.6
log_test "Verify USDT leverage after set" GET "/futures/BTCUSDT/leverage?is_symbol" "" "$(api_get '/futures/BTCUSDT/leverage?is_symbol&trade_currency=USDT')"
sleep 0.6

# Phase 3: Lists with currency filter
log_test "INR open positions" GET "/futures/positions?limit=5&trade_currency=INR" "" "$(api_get '/futures/positions?limit=5&trade_currency=INR')"
sleep 0.6
log_test "INR open orders" GET "/futures/orders?limit=5&trade_currency=INR" "" "$(api_get '/futures/orders?limit=5&trade_currency=INR')"
sleep 0.6
log_test "INR order history" GET "/futures/orders/history?limit=5&trade_currency=INR" "" "$(api_get '/futures/orders/history?limit=5&trade_currency=INR')"
sleep 0.6
log_test "INR position history" GET "/futures/positions/history?limit=5&trade_currency=INR" "" "$(api_get '/futures/positions/history?limit=5&trade_currency=INR')"
sleep 0.6

# Get BTC price for order test
ASSETS_RAW=$(api_get '/futures?limit=1&sort=popularity')
BTC_PRICE=$(echo "${ASSETS_RAW}" | sed 's/__HTTP_STATUS__:[0-9]*$//' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['price'])" 2>/dev/null || echo "100000")
sleep 0.6

# Phase 3: Place INR order (minimal - may fail on insufficient balance)
INR_ORDER_BODY=$(cat <<EOF
{
  "leverage": "2",
  "quantity": "0.001",
  "order_price": "${BTC_PRICE}",
  "order_type": "LONG",
  "trigger_type": "MARKET",
  "is_takeprofit": false,
  "is_stoploss": false,
  "reduce_only": false,
  "trade_currency": "INR"
}
EOF
)
log_test "Place INR-margin order BTCUSDT" POST "/futures/BTCUSDT/order?is_symbol" "${INR_ORDER_BODY}" "$(api_post '/futures/BTCUSDT/order?is_symbol' "${INR_ORDER_BODY}")"
sleep 0.6

# Re-check positions after order attempt
log_test "INR positions after order attempt" GET "/futures/positions?limit=5&trade_currency=INR" "" "$(api_get '/futures/positions?limit=5&trade_currency=INR')"

echo "Done. Results written to ${RESULTS_FILE}"
