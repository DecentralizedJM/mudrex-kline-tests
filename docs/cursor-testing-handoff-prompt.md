# Cursor Handoff — Mudrex API Testing (Full Context)

Copy everything between **PROMPT START** and **PROMPT END** into a new Cursor chat. Replace `YOUR_WORKSPACE` and base URLs as needed.

---

## PROMPT START

You are an API testing agent for **Mudrex Futures market data + Trade API**. The workspace is:

```
YOUR_WORKSPACE   # e.g. /Users/jm/Mudrex API Testing
```

Your job: run tests against **production or another environment** by overriding base URLs via environment variables. Document results. Do not commit unless asked.

---

### 1. What this repo tests

| Area | Host (default) | Auth |
|---|---|---|
| **Price REST** (klines, mark, last-price) | `https://price.mudrex.com/api/v1` | None |
| **Price WebSocket v2** (futures) | `wss://price.mudrex.com/api/v2/linear` | None |
| **Price WebSocket v2** (spot) | `wss://price.mudrex.com/api/v2/spot` | None |
| **Trade REST** (orders, positions, assets) | `https://trade.mudrex.com/fapi/v1` | `X-Authentication` header |

**Scope:** USDT linear futures market data + Trade API cross-checks. RexAlgo uPnL work is documented but not testable until Mudrex adds `unrealized_pnl`.

---

### 2. Override base URLs (staging / custom environment)

All harnesses read **environment variables**. No code changes needed to test another host.

#### Price REST

```bash
export MUDREX_PRICE_BASE_URL="https://price.staging.mudrex.com/api/v1"
# or internal: https://eu-west-1.dstaging.mudrex.intranet/api/v1
```

Used by: `price_rest_360.py`, `run_price_360.sh`, `curl/run_bulk_klines_tests.sh`

#### Price WebSocket

```bash
export MUDREX_WS_LINEAR_URL="wss://price.staging.mudrex.com/api/v2/linear"
export MUDREX_WS_SPOT_URL="wss://price.staging.mudrex.com/api/v2/spot"
export MUDREX_WS_V1_URL="wss://price.staging.mudrex.com/api/v1/klines?aggregation=1m&type=LINEAR&quote=usdt"
export MUDREX_WS_PING_INTERVAL=20
```

Used by: `price_ws_360.py`, `ws/price_websocket_v2_test.py`, `ws/stream_bulk_prices.sh` (via `WS_URL` or `MARKET`)

#### Trade REST

```bash
export MUDREX_BASE_URL="https://trade.mudrex.com/fapi/v1"
# staging if exists — confirm with team
export MUDREX_API_SECRET="your-api-secret-key"
```

Used by: `price_rest_360.py` (C8 cross-check), `testing/curl/common.sh`, INR tests

#### Test assets

```bash
export MUDREX_TEST_ASSET="btc/usdt"      # Price REST format
export MUDREX_TEST_ASSET2="eth/usdt"
export MUDREX_TEST_SYMBOL="BTCUSDT"      # Trade API format
export MUDREX_ASSET_TYPE="linear"        # futures
```

#### Output paths (optional)

```bash
export PRICE_REST_360_OUTPUT="testing/price-rest-360-results.json"
export PRICE_WS_360_OUTPUT="testing/price-ws-360-results.json"
```

#### Full staging example

```bash
cd "YOUR_WORKSPACE"

export MUDREX_PRICE_BASE_URL="https://price.staging.mudrex.com/api/v1"
export MUDREX_WS_LINEAR_URL="wss://price.staging.mudrex.com/api/v2/linear"
export MUDREX_WS_SPOT_URL="wss://price.staging.mudrex.com/api/v2/spot"
export MUDREX_BASE_URL="https://trade.mudrex.com/fapi/v1"
export MUDREX_API_SECRET="your-key"

bash testing/run_price_360.sh
```

#### Stream script with custom URL

```bash
WS_URL="wss://price.staging.mudrex.com/api/v2/linear" \
  ASSETS=btcusdt,ethusdt \
  bash testing/ws/stream_bulk_prices.sh

# All ~581 symbols (ticker only)
ASSETS=all MUDREX_API_SECRET="$MUDREX_API_SECRET" \
  bash testing/ws/stream_bulk_prices.sh
```

**WS URL derivation rule:** If you only change `MUDREX_PRICE_BASE_URL`, you must **also** set `MUDREX_WS_LINEAR_URL` / `MUDREX_WS_SPOT_URL` — REST and WS hosts are configured independently.

---

### 3. Test runners (run these)

| Command | What it does | Duration |
|---|---|---|
| `bash testing/run_price_360.sh` | Full REST + WS 360° + report | ~5–6 min |
| `python3 testing/price_rest_360.py` | REST only → JSON | ~1 min |
| `python3 testing/price_ws_360.py` | WS only → JSON | ~4–5 min |
| `python3 testing/generate_360_report.py` | Regenerate `Mark_Price_LTP_360_Test_Report.md` | seconds |
| `bash testing/curl/run_bulk_klines_tests.sh` | Bulk LTP + mark samples → markdown | seconds |
| `bash testing/curl/run_mark_price_klines_tests.sh` | Mark kline curl tests | seconds |
| `python3 testing/ws/price_websocket_v2_test.py --market linear --symbol btcusdt --streams kline,markKline,ticker --duration 45` | Interactive WS capture | ~45s |
| `bash testing/ws/stream_bulk_prices.sh` | Terminal price stream | until Ctrl+C |
| `bash testing/curl/run_inr_tests.sh` | INR margin Trade API tests | varies |

**Dependencies:**

```bash
pip3 install -r testing/ws/requirements.txt   # websockets
```

---

### 4. REST API contract (Price — futures)

**Base:** `$MUDREX_PRICE_BASE_URL` (default `https://price.mudrex.com/api/v1`)

#### Bulk LTP klines (works for single asset too)

```bash
curl "$MUDREX_PRICE_BASE_URL/assets/price?assets=btc/usdt&aggregation=1m&start_time=START&end_time=END&ohlcv=true&partial=true&type=linear"
```

Response: `data.asset_ticks["btc/usdt"]` → arrays of 6: `[open_time, o, h, l, c, volume]`

#### Bulk mark klines

```bash
curl "$MUDREX_PRICE_BASE_URL/assets/mark-price?assets=btc/usdt&aggregation=1m&start_time=START&end_time=END&ohlcv=true&type=linear"
```

5 fields per candle (no volume).

#### Bulk 4-param only (external API)

```bash
curl "$MUDREX_PRICE_BASE_URL/assets/price?assets=btc/usdt&aggregation=1m&start_time=START&end_time=END"
```

Close-only: `o,h,l,v=0`, price at index 4. Known issue **F1**.

#### Single-asset paths

| Path | Response key |
|---|---|
| `GET /asset/btc/usdt/klines?ohlcv=true&type=linear` | `data.ticks` |
| `GET /asset/btc/usdt/mark-price?ohlcv=true` | `data.ticks` |
| `GET /asset/btc/usdt/last-price?type=linear` | `data.price` |

#### Intervals (native — no aliases)

`1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth`

`3m`, `5m`, `15m`, `30m`, `1M` → **400** `aggregation not supported`

#### Pagination

No `limit` param. Max **1440 candles** per request. Paginate with `start_time`/`end_time` windows.

#### Symbol formats

| Surface | Format | Example |
|---|---|---|
| Price REST | lowercase slash | `btc/usdt` |
| Price WS | lowercase no slash | `btcusdt` |
| Trade API | uppercase | `BTCUSDT` |

#### Errors (Price REST)

```json
{"success":false,"errors":[{"code":400,"text":"end time should be greater than start time"}]}
{"success":false,"errors":[{"code":400,"text":"99x aggregation not supported"}]}
```

Future range → `200` with empty arrays.

---

### 5. WebSocket contract (Price v2)

**Linear:** `$MUDREX_WS_LINEAR_URL`  
**Spot:** `$MUDREX_WS_SPOT_URL`

#### Subscribe envelope

```json
{
    "id": 1,
    "method": "SUBSCRIBE",
    "params": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
    "assets": ["btcusdt"]
}
```

| Stream | Data |
|---|---|
| `ticker@5s` | `[{ "s": "btcusdt", "p": 63644, "mp": 63640 }]` — LTP + mark |
| `kline@1m@btcusdt` | `{ "s", "t", "o", "h", "l", "c", "v" }` |
| `markKline@1m@btcusdt` | `{ "s", "t", "o", "h", "l", "c" }` — linear only |
| `kline@1s@btcusdt` | ~1 push/sec |

**Limits:** 15 subscriptions per connection; 16th → `429 subscription limit reached`  
**Idle:** doc says 40s; may not close within 55s (W10)  
**All symbols:** `ticker@5s` with 581 assets in `assets` array works (1 subscription). Klines cannot do all symbols (15 sub cap).

#### WS errors

```json
{"method":"SUBSCRIBE","id":1,"error":{"code":400,"msg":"invalid stream name: kline@5m@btcusdt"}}
{"method":"SUBSCRIBE","id":16,"error":{"code":429,"msg":"subscription limit reached"}}
```

---

### 6. Trade API (for cross-checks only in price tests)

```bash
curl -H "X-Authentication: $MUDREX_API_SECRET" \
  "$MUDREX_BASE_URL/futures/positions"

curl -H "X-Authentication: $MUDREX_API_SECRET" \
  "$MUDREX_BASE_URL/futures/BTCUSDT?is_symbol"

curl -H "X-Authentication: $MUDREX_API_SECRET" \
  "$MUDREX_BASE_URL/futures/fee/history?limit=20"
```

Open positions: **no `unrealized_pnl`** today.

List all futures symbols (for `ASSETS=all`):

```bash
# Paginate GET /futures?limit=100&offset=N
# Cache: testing/all-futures-symbols.json (581 symbols as of 2026-06-20)
```

---

### 7. 360° test inventory

#### REST tests (`price_rest_360.py`) — 39 tests

| ID | Test | Expected |
|---|---|---|
| R1–R2 | Bulk LTP/mark full params | 200 |
| R3–R4 | Bulk external 4-param | 200, close-only (F1 fail by design) |
| R5 | Multi-asset bulk | 200 |
| R6a/b | partial true/false | 200 |
| R7a/b | type linear/spot | 200 |
| R8 | Single LTP klines | 200 |
| R9 | Single mark klines | 200 (was 404, fixed) |
| R10–R11 | last-price, point price | 200 |
| R12 | Bulk vs single close match | 200 |
| R-agg-* | All LINEAR aggregations | 200 |
| R13–R16 | Time boundaries | 200 |
| R17 | 1s klines duration=300 | **404** (known bug F7) |
| R18 | Invalid asset | 200 empty |
| R19 | Invalid agg 99x | 400 |
| R20–R21 | Asset format variants | 200 |
| R22 | Missing start_time | **200 wrong shape** (F5) |
| R23 | Mark bulk type=spot | 200 |
| C8 | Trade price vs last-price | 200 |

#### WS tests (`price_ws_360.py`) — 20 tests

| ID | Test | Notes |
|---|---|---|
| W1–W4 | Subscribe all streams | Timing flake possible |
| W5 | LIST_SUBSCRIPTIONS | `ticker_5s_assets` not `ticker_assets` (F2) |
| W6 | UNSUBSCRIBE | PASS |
| W9 | Ping 90s | PASS |
| W10 | Idle 45s | **FAIL** — not closed in 55s (F6) |
| W11–W16 | Negatives + 429 limit | PASS |
| W17 | Spot kline | PASS |
| W18 | Spot markKline rejected | PASS |
| W19 | Spot ticker no mp | PASS |
| W-v1 | WS v1 probe | PASS |
| C1–C4, C7 | REST vs WS cross-check | C1/C2 timing flake possible |

**Last production run:** 53 PASS / 6 FAIL (59 total)

---

### 8. Known issues register

| ID | Issue | Status |
|---|---|---|
| F1 | Bulk 4-param → close-only ticks | Open — PM |
| F2 | LIST_SUBSCRIPTIONS `ticker_5s_assets` | Doc fix |
| F4 | Single mark 404 | **Fixed** |
| F5 | Missing start_time → 200 not 400 | Open |
| F6 | WS idle timeout | Open |
| F7 | Single 1s klines 404 | Open |

---

### 9. Product decisions (do not contradict in docs/tests)

- Market data host: **`price.mudrex.com`** (not Trade API proxy)
- Price API: **no auth**
- Field names: **live API** (`p`, `mp`, array candles) — not PRD snake_case
- Pagination: `start_time`/`end_time`, 1440 cap — OK
- Intervals: `3t` not `3m` — no aliases
- Bulk endpoint works for single asset with `ohlcv=true&type=linear`
- Index/OI: not required
- Rex uPnL: needs Mudrex `unrealized_pnl` REST + account WS (not built)

---

### 10. Documentation files

| File | Purpose |
|---|---|
| `docs/futures-klines-and-price-websocket.md` | User-facing API doc |
| `docs/mark-price-ltp-failures.md` | Failures register |
| `docs/prd-market-data-gap-analysis.md` | PRD compliance |
| `docs/rexalgo-upnl-problem-and-solution.md` | Rex uPnL problem |
| `docs/claude-cowork-handoff-prompt.md` | Rex/product handoff |
| `Mark_Price_LTP_360_Test_Report.md` | Latest 360 report |

---

### 11. Test artifacts (generated)

| File | Contents |
|---|---|
| `testing/price-rest-360-results.json` | REST JSON results |
| `testing/price-ws-360-results.json` | WS JSON results |
| `testing/bulk-klines-test-results.md` | Sample responses |
| `testing/bulk-vs-single-klines.json` | Proof bulk = single |
| `testing/btc-1h-ohlcv-now.json` | Latest 1h sample |
| `testing/all-futures-symbols.json` | 581 WS symbols |
| `testing/prd-market-data-detail.json` | PRD probes |
| `testing/ws/price-v2-capture.jsonl` | WS message capture |

---

### 12. Quick manual tests (copy-paste)

```bash
cd "YOUR_WORKSPACE"
NOW=$(date +%s); START=$((NOW - 3600))

# Health: bulk LTP
curl -s "$MUDREX_PRICE_BASE_URL/assets/price?assets=btc/usdt&aggregation=1m&start_time=$START&end_time=$NOW&ohlcv=true&type=linear" | python3 -m json.tool | head -30

# Health: bulk mark
curl -s "$MUDREX_PRICE_BASE_URL/assets/mark-price?assets=btc/usdt&aggregation=1m&start_time=$START&end_time=$NOW&ohlcv=true" | python3 -m json.tool | head -20

# Stream live prices
ASSETS=btcusdt,ethusdt bash testing/ws/stream_bulk_prices.sh

# Stream ALL symbols
ASSETS=all bash testing/ws/stream_bulk_prices.sh

# Continuous ~1/sec
CONTINUOUS=1 ASSETS=btcusdt bash testing/ws/stream_bulk_prices.sh
```

---

### 13. Instructions for you (Cursor agent)

1. **Confirm workspace** exists and `testing/run_price_360.sh` is present.
2. **Ask user** for target environment URLs if not provided (Price REST, WS linear, Trade).
3. **Export env vars** before running — never hardcode secrets in commits.
4. Run `bash testing/run_price_360.sh` (or subset) against target.
5. Compare results to known issues (§8); flag **new** failures vs environment-specific breaks.
6. If staging behaves differently, document delta in a new markdown report under repo root or `testing/`.
7. For WS timing flakes (W1-W4, C1/C2), re-run once before filing bugs.
8. Do not edit `.cursor/plans/` files.
9. Do not commit unless user asks.

**User's task:** [DESCRIBE HERE — e.g. "Run full 360 against staging URLs", "Compare staging vs prod", "Verify bulk klines on new base URL", etc.]

**Target URLs (fill in):**

```
MUDREX_PRICE_BASE_URL=
MUDREX_WS_LINEAR_URL=
MUDREX_WS_SPOT_URL=
MUDREX_BASE_URL=
MUDREX_API_SECRET=        # optional for price-only tests; required for Trade/C8/ASSETS=all refresh
```

## PROMPT END
