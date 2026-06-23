# Mudrex Kline & Price API Tests

Full test harness, documentation, and handoff prompts for **Mudrex Futures market data** (Price REST + WebSocket) and **Trade API** cross-checks.

**Last production 360° run:** 53 PASS / 6 FAIL (59 tests) — see [`Mark_Price_LTP_360_Test_Report.md`](Mark_Price_LTP_360_Test_Report.md)

---

## Quick start (any machine)

```bash
git clone https://github.com/DecentralizedJM/mudrex-kline-tests.git
cd mudrex-kline-tests

cp .env.example .env          # add your MUDREX_API_SECRET
pip3 install -r testing/ws/requirements.txt

# Full REST + WS 360° suite (~5–6 min)
bash testing/run_price_360.sh

# Stream live prices in terminal
ASSETS=btcusdt,ethusdt bash testing/ws/stream_bulk_prices.sh
ASSETS=all bash testing/ws/stream_bulk_prices.sh          # 581 symbols via ticker@5s
CONTINUOUS=1 ASSETS=btcusdt bash testing/ws/stream_bulk_prices.sh  # ~1/sec klines
```

**Price API tests need no auth.** Trade cross-checks (C8) and `ASSETS=all` symbol refresh need `MUDREX_API_SECRET`.

---

## Cursor / AI handoff prompts

Copy-paste these into a new chat on **any computer** — no local file paths required:

| File | Use for |
|---|---|
| [`docs/cursor-testing-handoff-prompt.md`](docs/cursor-testing-handoff-prompt.md) | **Full Cursor testing prompt** — env vars, API contracts, 59-test inventory, known issues |
| [`docs/claude-cowork-handoff-prompt.md`](docs/claude-cowork-handoff-prompt.md) | Rex/product handoff — uPnL, PRD gaps, engineering tickets |

Open `docs/cursor-testing-handoff-prompt.md` and copy everything between **PROMPT START** and **PROMPT END**.

---

## API surfaces

| Area | Default host | Auth |
|---|---|---|
| Price REST | `https://price.mudrex.com/api/v1` | None |
| Price WS futures | `wss://price.mudrex.com/api/v2/linear` | None |
| Price WS spot | `wss://price.mudrex.com/api/v2/spot` | None |
| Trade REST | `https://trade.mudrex.com/fapi/v1` | `X-Authentication` header |

### Symbol formats

| Surface | Example |
|---|---|
| Price REST | `btc/usdt` |
| Price WS | `btcusdt` |
| Trade API | `BTCUSDT` |

---

## Environment variables

```bash
# Price REST
export MUDREX_PRICE_BASE_URL="https://price.mudrex.com/api/v1"

# Price WebSocket (set separately — NOT derived from REST URL)
export MUDREX_WS_LINEAR_URL="wss://price.mudrex.com/api/v2/linear"
export MUDREX_WS_SPOT_URL="wss://price.mudrex.com/api/v2/spot"
export MUDREX_WS_V1_URL="wss://price.mudrex.com/api/v1/klines?aggregation=1m&type=LINEAR&quote=usdt"
export MUDREX_WS_PING_INTERVAL=20

# Trade API
export MUDREX_BASE_URL="https://trade.mudrex.com/fapi/v1"
export MUDREX_API_SECRET="your-api-secret"

# Test assets
export MUDREX_TEST_ASSET="btc/usdt"
export MUDREX_TEST_ASSET2="eth/usdt"
export MUDREX_TEST_SYMBOL="BTCUSDT"
export MUDREX_ASSET_TYPE="linear"
```

**Staging example:**

```bash
export MUDREX_PRICE_BASE_URL="https://price.staging.mudrex.com/api/v1"
export MUDREX_WS_LINEAR_URL="wss://price.staging.mudrex.com/api/v2/linear"
export MUDREX_WS_SPOT_URL="wss://price.staging.mudrex.com/api/v2/spot"
```

---

## Test runners

| Command | Purpose |
|---|---|
| `bash testing/run_price_360.sh` | Full REST + WS 360° + report |
| `python3 testing/price_rest_360.py` | REST only → JSON |
| `python3 testing/price_ws_360.py` | WS only → JSON |
| `python3 testing/generate_360_report.py` | Regenerate 360 report |
| `bash testing/curl/run_bulk_klines_tests.sh` | Bulk LTP/mark samples |
| `bash testing/curl/run_mark_price_klines_tests.sh` | Mark kline curl tests |
| `bash testing/curl/run_inr_tests.sh` | INR margin Trade API tests |
| `bash testing/ws/stream_bulk_prices.sh` | Terminal price stream |

---

## Price REST (futures)

**Bulk LTP** (works for single asset — identical to single `/klines` with `ohlcv=true&type=linear`):

```
GET /assets/price?assets=btc/usdt&aggregation=1m&start_time=&end_time=&ohlcv=true&type=linear
→ data.asset_ticks["btc/usdt"] = [open_time, o, h, l, c, volume]  (6 fields)
```

**Bulk mark:**

```
GET /assets/mark-price?assets=btc/usdt&aggregation=1m&start_time=&end_time=&ohlcv=true&type=linear
→ 5 fields per candle (no volume)
```

**Bulk 4-param only** (external API — close-only, issue F1):

```
GET /assets/price?assets=btc/usdt&aggregation=1m&start_time=&end_time=
→ o,h,l,v=0; close at index 4
```

**Single asset:**

- `GET /asset/btc/usdt/klines?ohlcv=true&type=linear` → `data.ticks`
- `GET /asset/btc/usdt/mark-price?ohlcv=true` → `data.ticks`
- `GET /asset/btc/usdt/last-price?type=linear` → `data.price`

**Intervals (native — no aliases):** `1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth`

`3m`, `5m`, `15m`, `30m`, `1M` → 400 `aggregation not supported`

**Pagination:** max 1440 candles/request; chain `start_time`/`end_time` windows.

---

## Price WebSocket v2

**Subscribe:**

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
| `ticker@5s` | `[{ "s": "btcusdt", "p": 63644, "mp": 63640 }]` — LTP + mark every ~5s |
| `kline@1m@sym` | `{ s, t, o, h, l, c, v }` — LTP candle |
| `markKline@1m@sym` | `{ s, t, o, h, l, c }` — mark candle (linear only) |
| `kline@1s@sym` | ~1 push/sec (max 15 subs per connection) |

**Limits:** 15 subscriptions/connection. All 581 symbols work in one `ticker@5s` + assets array.

---

## Known issues (production, 2026-06-20)

| ID | Issue | Status |
|---|---|---|
| F1 | Bulk 4-param → close-only ticks | Open — PM decision |
| F2 | LIST_SUBSCRIPTIONS uses `ticker_5s_assets` not `ticker_assets` | Doc fix |
| F4 | Single mark 404 | **Fixed** |
| F5 | Missing start_time → 200 not 400 | Open |
| F6 | WS idle timeout not enforced in 55s | Open |
| F7 | Single 1s klines 404 | Open |

Details: [`docs/mark-price-ltp-failures.md`](docs/mark-price-ltp-failures.md)

---

## Product decisions (confirmed)

- Market data on `price.mudrex.com` (not Trade API proxy)
- Price API: **no auth**
- Field names: live API (`p`, `mp`, array candles) — not PRD snake_case
- Pagination: `start_time`/`end_time`, 1440 cap — OK
- Intervals: `3t` not `3m` — no aliases
- Bulk endpoint = single asset when `ohlcv=true&type=linear`
- Index/OI: not required
- Rex uPnL: needs Mudrex `unrealized_pnl` on REST + account WS (not built yet)

---

## RexAlgo uPnL gap

`GET /futures/positions` has **no `unrealized_pnl`**. Price WS has `mp` but no position context. Rex must not compute uPnL client-side.

**Mudrex must build:** `unrealized_pnl`, `mark_price`, `computed_at` on positions REST + authenticated account WebSocket.

See: [`docs/rexalgo-upnl-problem-and-solution.md`](docs/rexalgo-upnl-problem-and-solution.md), [`docs/eng-ticket-unrealized-pnl-positions.md`](docs/eng-ticket-unrealized-pnl-positions.md)

---

## Documentation index

### Market data & WebSocket

- [`docs/futures-klines-and-price-websocket.md`](docs/futures-klines-and-price-websocket.md) — user-facing API doc
- [`docs/mark-price-ltp-websocket-api.md`](docs/mark-price-ltp-websocket-api.md) — internal API reference
- [`docs/price-websocket-v2-contract.md`](docs/price-websocket-v2-contract.md) — WS contract
- [`docs/data-read-client-api-contract.md`](docs/data-read-client-api-contract.md) — data read client contract
- [`docs/prd-market-data-gap-analysis.md`](docs/prd-market-data-gap-analysis.md) — PRD vs live gap matrix

### Rex / uPnL

- [`docs/rexalgo-upnl-problem-and-solution.md`](docs/rexalgo-upnl-problem-and-solution.md)
- [`docs/rexalgo-streaming-upnl-solution.md`](docs/rexalgo-streaming-upnl-solution.md)
- [`docs/unrealized-pnl-price-websocket-strategy.md`](docs/unrealized-pnl-price-websocket-strategy.md)

### INR margin / Trade API

- [`docs/inr-margin-api-reference.md`](docs/inr-margin-api-reference.md)
- [`docs/quickstart-inr.md`](docs/quickstart-inr.md)
- [`INR_Futures_API_Testing_Report.md`](INR_Futures_API_Testing_Report.md)

### Test reports

- [`Mark_Price_LTP_360_Test_Report.md`](Mark_Price_LTP_360_Test_Report.md) — master 360° report
- [`Mark_Price_LTP_WebSocket_Test_Report.md`](Mark_Price_LTP_WebSocket_Test_Report.md)
- [`testing/MARK_PRICE_LTP_KLINES_WS_TEST_PLAN.md`](testing/MARK_PRICE_LTP_KLINES_WS_TEST_PLAN.md)

---

## Test artifacts (checked in)

| File | Contents |
|---|---|
| `testing/price-rest-360-results.json` | REST JSON results |
| `testing/price-ws-360-results.json` | WS JSON results |
| `testing/bulk-vs-single-klines.json` | Proof bulk = single |
| `testing/all-futures-symbols.json` | 581 WS symbols |
| `testing/btc-1h-ohlcv-now.json` | Sample 1h OHLCV |
| `testing/prd-market-data-detail.json` | PRD probes |

---

## Repo structure

```
testing/
  run_price_360.sh           # top-level 360 runner
  price_rest_360.py          # REST test suite
  price_ws_360.py            # WebSocket test suite
  generate_360_report.py     # report generator
  ws/
    stream_bulk_prices.sh    # terminal price stream
    price_websocket_v2_test.py
    requirements.txt         # pip: websockets
  curl/
    common.sh                # Trade API helpers
    run_bulk_klines_tests.sh
    run_inr_tests.sh
docs/                        # API docs + handoff prompts
```

---

## License

Internal Mudrex / Rex testing material. Use API secrets via `.env` only — never commit `.env`.
