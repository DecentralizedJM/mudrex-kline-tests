# Mark Price / LTP / WebSocket — 360° Test Report

**REST generated:** 2026-06-20T04:05:26Z
**WS generated:** 2026-06-20T04:10:30.254939+00:00
**Environment:** Production (`price.mudrex.com`)
**Trading key:** Verified on `trade.mudrex.com` (INR futures funds)

---

## Summary

**Score: 53 PASS, 6 FAIL** (total 59 tests)

| # | ID | Cat | Test | Result | HTTP | Notes |
|---|---|---|---|---|---|---|
| 1 | R1 | REST | Bulk LTP full params | PASS | 200 |  |
| 2 | R2 | REST | Bulk mark full params | PASS | 200 |  |
| 3 | R3 | REST | Bulk LTP external-only (4 params) | **FAIL** | 200 | F1: PM external param set |
| 4 | R4 | REST | Bulk mark external-only | **FAIL** | 200 |  |
| 5 | R5 | REST | Multi-asset bulk LTP | PASS | 200 |  |
| 6 | R6a | REST | Bulk LTP partial=true | PASS | 200 |  |
| 7 | R6b | REST | Bulk LTP partial=false | PASS | 200 |  |
| 8 | R7a | REST | Bulk LTP type=linear | PASS | 200 |  |
| 9 | R7b | REST | Bulk LTP type=spot | PASS | 200 |  |
| 10 | R8 | REST | Single LTP klines | PASS | 200 |  |
| 11 | R9 | REST | Single mark klines | PASS | 200 |  |
| 12 | R10 | REST | Last price LTP | PASS | 200 |  |
| 13 | R11 | REST | Point price no ohlcv | PASS | 200 |  |
| 14 | R12 | REST | Bulk vs single LTP close | PASS | 200 | bulk=63399.3 single=63399.3 |
| 15 | R-agg-1m | REST | Aggregation 1m | PASS | 200 | 90d window for 1w/1mth else 24h |
| 16 | R-agg-3t | REST | Aggregation 3t | PASS | 200 | 90d window for 1w/1mth else 24h |
| 17 | R-agg-5t | REST | Aggregation 5t | PASS | 200 | 90d window for 1w/1mth else 24h |
| 18 | R-agg-10t | REST | Aggregation 10t | PASS | 200 | 90d window for 1w/1mth else 24h |
| 19 | R-agg-15t | REST | Aggregation 15t | PASS | 200 | 90d window for 1w/1mth else 24h |
| 20 | R-agg-30t | REST | Aggregation 30t | PASS | 200 | 90d window for 1w/1mth else 24h |
| 21 | R-agg-1h | REST | Aggregation 1h | PASS | 200 | 90d window for 1w/1mth else 24h |
| 22 | R-agg-4h | REST | Aggregation 4h | PASS | 200 | 90d window for 1w/1mth else 24h |
| 23 | R-agg-6h | REST | Aggregation 6h | PASS | 200 | 90d window for 1w/1mth else 24h |
| 24 | R-agg-12h | REST | Aggregation 12h | PASS | 200 | 90d window for 1w/1mth else 24h |
| 25 | R-agg-1d | REST | Aggregation 1d | PASS | 200 | 90d window for 1w/1mth else 24h |
| 26 | R-agg-1w | REST | Aggregation 1w | PASS | 200 | 90d window for 1w/1mth else 24h |
| 27 | R-agg-1mth | REST | Aggregation 1mth | PASS | 200 | 90d window for 1w/1mth else 24h |
| 28 | R13 | REST | start_time == end_time | PASS | 200 |  |
| 29 | R14 | REST | start_time > end_time | PASS | 400 |  |
| 30 | R15 | REST | Future end_time | PASS | 200 |  |
| 31 | R16 | REST | Very old range 2020 | PASS | 200 |  |
| 32 | R17 | REST | 1s klines duration=300 | **FAIL** | 404 |  |
| 33 | R18 | REST | Invalid asset foo/bar | PASS | 200 |  |
| 34 | R19 | REST | Invalid aggregation 99x | PASS | 400 |  |
| 35 | R20 | REST | Asset format btcusdt no slash | PASS | 200 |  |
| 36 | R21 | REST | Uppercase BTC/USDT | PASS | 200 |  |
| 37 | R22 | REST | Missing start_time | **FAIL** | 200 |  |
| 38 | R23 | REST | Mark bulk type=spot | PASS | 200 |  |
| 39 | C8 | REST | Trading API price vs last-price | PASS | 200 | trade=63399.3 last=63399.3 diff=0.000% |
| 40 | W1-W4 | WS | Linear subscribe all streams | **FAIL** | — | streams={'ticker@5s', 'kline@1s@btcusdt'} |
| 41 | W5 | WS | LIST_SUBSCRIPTIONS field names | PASS | — | F2 documentation mismatch flagged |
| 42 | W6 | WS | UNSUBSCRIBE kline stops pushes | PASS | — | pushes_after=0 |
| 43 | W9 | WS | Ping keepalive 90s | PASS | — | 4 pings over ~80s |
| 44 | W10 | WS | Idle 45s closes connection | **FAIL** | — | closed=False |
| 45 | W11 | WS | Invalid stream kline@5m | PASS | — |  |
| 46 | W12 | WS | Mixed valid+invalid all-or-nothing | PASS | — |  |
| 47 | W13 | WS | Unknown method FOO | PASS | — |  |
| 48 | W14 | WS | Malformed JSON | PASS | — |  |
| 49 | W15 | WS | UNSUBSCRIBE not subscribed | PASS | — |  |
| 50 | W16 | WS | 16th subscription 429 limit | PASS | — | hit_429=True |
| 51 | W17 | WS | Spot kline subscribe + push | PASS | — | got_kline=True |
| 52 | W18 | WS | Spot markKline rejected | PASS | — | linear-only per contract |
| 53 | W19 | WS | Spot ticker no mp field | PASS | — |  |
| 54 | W-v1 | WS | WS v1 legacy probe | PASS | — | probe only |
| 55 | C1 | WS | REST LTP close vs WS kline c | PASS | — | rest=63394 ws=63370.1 |
| 56 | C2 | WS | REST mark close vs WS markKline c | PASS | — | rest=63396.67 ws=63374.63 |
| 57 | C3 | WS | WS ticker p vs REST last-price | PASS | — | last=63394 ticker=63372.1 |
| 58 | C4 | WS | WS ticker mp vs REST mark close | PASS | — | mark=63396.67 mp=63372.98 |
| 59 | C7 | WS | Mark vs LTP close differ | PASS | — | ltp=63394 mark=63396.67 |

---

## Issues Register

### F1 [PM] External 4 params without ohlcv returns o,h,l,v=0

PM limits external users to `assets`, `aggregation`, `start_time`, `end_time`. Without `ohlcv`, candles return zeros except close at index 4.

### F2 [DOC] LIST_SUBSCRIPTIONS field names

Doc says `ticker_assets`; live API returns `ticker_5s_assets` and `ticker_1s_assets`.

### F3 [INFO] Mark vs LTP closes differ

Expected — mark is fair-value; LTP is last traded price.

### F4 [BUG] Single-asset mark-price path 404

`GET /asset/btc/usdt/mark-price` returns 404; bulk `/assets/mark-price` works.

### F5 [BUG] Missing start_time returns 200

Bulk klines without `start_time` returns 200 point-price shape instead of 400.

### F6 [BUG/DOC] WS idle timeout

Doc says 40s inactivity close; may not fire within 55s on prod.

### F7 [BUG] Single-asset 1s klines 404

`GET /asset/btc/usdt/klines?aggregation=1s&duration=300` returns asset not found.

### Confirmed in this test run

- **R3:** PM-F1: external params return o,h,l=0 — close-only at index 4
- **R4:** PM-F1: external params return o,h,l=0 — close-only at index 4
- **R17:** BUG: single-asset 1s klines not found — check path or type param
- **R22:** BUG: missing start_time returns 200 (point price) instead of 400
- **W1-W4:** no kline@1m push
- **W1-W4:** no markKline push
- **W10:** BUG: idle timeout not enforced within 55s
- **W10:** 

---

## Failed tests

### R3 — Bulk LTP external-only (4 params)

**URL:** `https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&aggregation=1m&start_time=1781924704&end_time=1781928304`
**HTTP:** 200

- PM-F1: external params return o,h,l=0 — close-only at index 4

### R4 — Bulk mark external-only

**URL:** `https://price.mudrex.com/api/v1/assets/mark-price?assets=btc/usdt&aggregation=1m&start_time=1781924704&end_time=1781928304`
**HTTP:** 200

- PM-F1: external params return o,h,l=0 — close-only at index 4

### R17 — 1s klines duration=300

**URL:** `https://price.mudrex.com/api/v1/asset/btc/usdt/klines?aggregation=1s&duration=300&ohlcv=true&type=linear`
**HTTP:** 404

- BUG: single-asset 1s klines not found — check path or type param

### R22 — Missing start_time

**URL:** `https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&aggregation=1m&end_time=1781928304&ohlcv=true&partial=true&type=linear`
**HTTP:** 200

- BUG: missing start_time returns 200 (point price) instead of 400

### W1-W4 — Linear subscribe all streams

**URL:** `wss://price.mudrex.com/api/v2/linear`
**HTTP:** —

- no kline@1m push
- no markKline push

### W10 — Idle 45s closes connection

**URL:** `wss://price.mudrex.com/api/v2/linear`
**HTTP:** —

- BUG: idle timeout not enforced within 55s
- 

---

## Key request / response samples

### Bulk LTP klines (full params)

```bash
curl "https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time=START&end_time=END&partial=true&type=linear"
```

Response shape: `data.asset_ticks["btc/usdt"]` → `[time, o, h, l, c, volume]` (6 fields)

### Bulk mark klines

```bash
curl "https://price.mudrex.com/api/v1/assets/mark-price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time=START&end_time=END&partial=true&type=linear"
```

Response shape: 5 fields — no volume

### WS v2 linear subscribe

```json
{ "id": 1, "method": "SUBSCRIBE", "params": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"], "assets": ["btcusdt"] }
```

---

## Recommendations

1. **PM:** Resolve F1 — document whether external users get full OHLCV or close-only ticks.
2. **Docs:** Fix F2 `ticker_5s_assets` in LIST_SUBSCRIPTIONS response.
3. **Engineering:** Fix F4 single-asset mark-price 404 or document bulk-only.
4. **Engineering:** Fix F5 — validate required params return 400.
5. **Engineering:** Clarify F6 idle timeout behavior on production.
6. **Docs:** REST uses `btc/usdt`; WS uses `btcusdt`.
7. **PM:** Confirm rate limit policy before external launch.

---

## Raw files

- `testing/price-rest-360-results.json` — {'total': 39, 'pass': 35, 'fail': 4}
- `testing/price-ws-360-results.json` — {'total': 20, 'pass': 18, 'fail': 2}
- `testing/bulk-klines-test-results.md`
- `testing/ws/price-v2-capture.jsonl`
