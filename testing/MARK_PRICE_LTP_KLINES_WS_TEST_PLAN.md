# Mark Price, LTP Klines & Price WebSocket — Test Plan

**Status:** Contract received — ready to test Data Read Client  
**Prepared:** 2026-06-15  
**Reference:** [`docs/data-read-client-api-contract.md`](../docs/data-read-client-api-contract.md)

> **Important:** This is the **Data Read Client** (`price.mudrex.com/api/v1`), **not** the trading API (`trade.mudrex.com/fapi/v1`). Earlier probes on `/fapi/v1/futures/.../klines` returned 404 because klines live on the price service.

---

## Scope

| Feature | Type | API (Data Read Client) |
|---|---|---|
| Mark price klines | REST | `GET /api/v1/assets/mark-price?assets=btc/usdt&aggregation=1m&start_time&end_time` |
| LTP klines (bulk) | REST | `GET /api/v1/assets/price?assets=btc/usdt&aggregation=1m&start_time&end_time` |
| Mark price (point) | REST | `GET /api/v1/assets/mark-price?assets=...` |
| LTP (last price) | REST | `GET /api/v1/asset/:base/:quote/last-price?type=LINEAR` |
| Realtime klines WS | WebSocket | `wss://price.mudrex.com/api/v2/linear` (JSON SUBSCRIBE) |
| Legacy raw klines WS | WebSocket | `wss://price.mudrex.com/api/v1/klines` (query params) |

**Futures/perps:** use **`/api/v2/linear`** for WS; REST uses `type=LINEAR`.

**WS v2 contract:** [`docs/price-websocket-v2-contract.md`](../docs/price-websocket-v2-contract.md)

---

## Resolved contract (from engineering)

| # | Question | Answer |
|---|---|---|
| 1 | REST base | `https://price.mudrex.com/api/v1` (staging: `price.staging.mudrex.com`) |
| 2 | Mark vs LTP | **Separate paths** — mark: `.../mark-price`; LTP: `.../klines` or `.../last-price` |
| 3 | Intervals (LINEAR) | `1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth` |
| 4 | Time range | `start_time`, `end_time` (Unix seconds, inclusive) |
| 5 | External params only | `assets`, `aggregation`, `start_time`, `end_time` |
| 6 | Asset format (REST) | `btc/usdt` (slash); WS v2 uses `btcusdt` |
| 7 | LTP response | `data.asset_ticks["btc/usdt"]` — arrays of 6 values |
| 8 | Mark response | Same structure — arrays of 5 values (no volume) |
| 9 | Rate limits | **None currently** — test carefully; policy TBD 16 June |
| 10 | Availability | Not on prod/sandbox at thread time; sandbox + prod push expected |

---

## Test environment

```bash
cp .env.example .env
# Set MUDREX_API_SECRET and optionally override URLs below
```

| Variable | Default | Purpose |
|---|---|---|
| `MUDREX_PRICE_BASE_URL` | `https://price.mudrex.com/api/v1` | Data Read Client REST |
| `MUDREX_WS_LINEAR_URL` | `wss://price.mudrex.com/api/v2/linear` | Futures WS v2 |
| `MUDREX_WS_SPOT_URL` | `wss://price.mudrex.com/api/v2/spot` | Spot WS v2 |
| `MUDREX_TEST_BASE` | `BTC` | Base currency |
| `MUDREX_TEST_QUOTE` | `USDT` | Quote currency |
| `MUDREX_ASSET_TYPE` | `LINEAR` | Futures/perps |

---

## REST test matrix — Klines

| # | Test | Expected |
|---|---|---|
| K1 | Mark klines — default params | `200`, non-empty candles, valid OHLC |
| K2 | LTP klines — same interval/limit | `200`, non-empty candles, valid OHLC |
| K3 | Mark vs LTP differ | Same symbol/interval; close prices may differ (not identical series) |
| K4 | Intervals | Each documented interval returns data |
| K5 | `limit=1` | Single candle returned |
| K6 | `limit` max | Respects max; no server error |
| K7 | Invalid interval | `400` with clear error |
| K8 | Invalid symbol | `404` or `400` |
| K9 | Unknown price type | `400` if param invalid |
| K10 | `start_time` / `end_time` filter | Only candles in range |
| K11 | Candle ordering | Ascending by open time (confirm) |
| K12 | OHLC sanity | `low <= open,close <= high` per candle |
| K13 | Timestamps | UTC; consecutive 1m candles ~60s apart |
| K14 | Cross-check mark vs asset `price` | Latest mark close roughly aligns with mark used internally (tolerance TBD) |
| K15 | Cross-check LTP | Latest LTP close aligns with recent trade prints (tolerance TBD) |
| K16 | No auth (if public) | Works without header |
| K17 | With auth | Works with `X-Authentication` |
| K18 | Rate limit | 10 req/s default; no unexpected 429 |

---

## WebSocket v2 test matrix — Price feed (`/api/v2/linear`)

| # | Test | Expected |
|---|---|---|
| W1 | Connect to `/api/v2/linear` | Connection succeeds, no auth |
| W2 | SUBSCRIBE `kline@1m@btcusdt` | `{ result: "success" }` then push with `stream` + OHLCV |
| W3 | SUBSCRIBE `markKline@1m@btcusdt` | Push without `v` field |
| W4 | SUBSCRIBE `ticker@5s` + assets | Immediate snapshot, then 5s pushes with `p` and `mp` |
| W5 | Mark kline on spot endpoint | Rejected — linear only |
| W6 | Invalid stream `kline@5m@btcusdt` | 400 all-or-nothing reject |
| W7 | LIST_SUBSCRIPTIONS | Returns active streams + ticker_assets |
| W8 | UNSUBSCRIBE kline | Stops kline pushes |
| W9 | 16th subscription | 429 subscription limit reached |
| W10 | Idle 40s without ping | Connection closed |
| W11 | PING every 20s | Connection stays open |
| W12 | Reconnect | Must re-SUBSCRIBE all streams |

---

## How to run (once contract is filled in)

### REST klines

```bash
cd "/Users/jm/Mudrex API Testing"
# Edit paths/params at top of script if engineering changes contract
bash testing/curl/run_mark_price_klines_tests.sh
```

Output: `testing/mark-price-klines-test-results.md`

### WebSocket v2 (linear)

```bash
pip install -r testing/ws/requirements.txt
python3 testing/ws/price_websocket_v2_test.py --market linear --symbol btcusdt --streams kline,markKline,ticker --duration 45 --list-subs
```

Output: `testing/ws/price-v2-capture.jsonl`

### WebSocket v1 (legacy — query params)

```bash
python3 testing/ws/price_websocket_test.py --url "wss://price.mudrex.com/api/v1/klines?aggregation=1m&type=LINEAR&quote=usdt" --duration 30
```

---

## Validation notes

**Mark price vs LTP**

- Mark should be smoother; large single-trade wicks on LTP may not appear on mark.
- Both are USDT-denominated (same as existing contract prices).
- Do not expect mark klines === LTP klines for the same window.

**Kline sample checks**

- First candle `open_time` ≤ last candle `open_time`
- No duplicate open times
- `high >= low` always

**Documentation samples**

- Sample JSON must match the cURL filters (same rule as transactions docs).
- Separate examples for mark and LTP — do not mix in one response block.

---

## Contract appendix (paste engineer samples here)

### Mark price klines — REST

```
# TBD — paste engineer cURL + sample response
```

### LTP klines — REST

```
# TBD — paste engineer cURL + sample response
```

### Price WebSocket

```
# TBD — paste WS URL, subscribe message, sample messages
```

---

## Files in this workspace

| File | Purpose |
|---|---|
| `testing/MARK_PRICE_LTP_KLINES_WS_TEST_PLAN.md` | This plan |
| `testing/curl/run_mark_price_klines_tests.sh` | REST test runner |
| `testing/ws/price_websocket_test.py` | WebSocket capture script |
| `testing/ws/requirements.txt` | Python deps for WS tests |

---

## Next steps

1. Get engineer contract (paths, params, WS schema) → fill appendix + script config vars  
2. Confirm environment URL (prod vs staging)  
3. Run REST script → capture pass/fail + raw responses  
4. Run WS script → validate live ticks vs klines  
5. Write final test report (same format as `INR_Futures_API_Testing_Report.md`)
