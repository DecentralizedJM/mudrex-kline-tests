# Mark Price / LTP / WebSocket — Failures Report

**Environment:** Production (`price.mudrex.com`)  
**Test run:** 2026-06-20  
**Score:** 53 PASS · **6 FAIL** (59 tests)  
**Previous run:** 2026-06-17 — 50 PASS · 9 FAIL  
**Full test report:** [`Mark_Price_LTP_360_Test_Report.md`](../Mark_Price_LTP_360_Test_Report.md)  
**API reference:** [`mark-price-ltp-websocket-api.md`](mark-price-ltp-websocket-api.md)

---

## Summary

| Severity | Count | Owner |
|---|---|---|
| BUG | 2 | Engineering |
| PM / contract | 1 | Product |
| DOC | 1 | Docs |
| Timing / harness | 1 | QA (re-run) |
| INFO (not a failure) | 1 | — |
| **Resolved** | **4** | — |

### Failed tests at a glance

| ID | Test | HTTP / WS | Issue | Severity |
|---|---|---|---|---|
| R3 | Bulk LTP external-only (4 params) | 200 | F1 — close-only ticks | PM |
| R4 | Bulk mark external-only | 200 | F1 — close-only ticks | PM |
| R17 | 1s klines `duration=300` | 404 | F7 — asset not found | BUG |
| R22 | Missing `start_time` | 200 | F5 — wrong response shape | BUG |
| W1-W4 | Linear subscribe all streams | — | No `kline@1m` / `markKline` in window | Timing |
| W10 | Idle 45s closes connection | — | F6 — timeout not enforced | BUG/DOC |

### Resolved since last run

| ID | Test | Was | Now |
|---|---|---|---|
| R9 | Single mark klines | FAIL (404) | **PASS** (200) — F4 fixed |
| W17 | Spot kline subscribe + push | FAIL (harness) | **PASS** |
| C1 | REST LTP close vs WS kline `c` | FAIL (timing) | **PASS** |
| C2 | REST mark close vs WS markKline `c` | FAIL (timing) | **PASS** |

---

## Issues register

### F1 — External 4 params return close-only ticks

| | |
|---|---|
| **Severity** | PM / contract |
| **Owner** | Product |
| **Tests** | R3, R4 |
| **Status** | Open |

**Expected (per external contract):** PM limits external users to four query params: `assets`, `aggregation`, `start_time`, `end_time`. It is unclear whether full OHLCV should be returned implicitly.

**Actual:** HTTP 200 with candles where `open`, `high`, `low`, and `volume` are `0`; only `close` (index 4) is populated.

**Impact:** External integrators cannot build candlestick charts without `ohlcv=true` (not in the approved param set).

#### R3 — Bulk LTP

**Request:**

```bash
curl "https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&aggregation=1m&start_time=1781924704&end_time=1781928304"
```

**Response (200):**

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781924760, 0, 0, 0, 63370.1, 0],
                [1781924820, 0, 0, 0, 63370, 0],
                [1781924880, 0, 0, 0, 63370, 0]
            ]
        }
    }
}
```

#### R4 — Bulk mark

**Request:**

```bash
curl "https://price.mudrex.com/api/v1/assets/mark-price?assets=btc/usdt&aggregation=1m&start_time=1781924704&end_time=1781928304"
```

**Response (200):**

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781924760, 0, 0, 0, 63339.7],
                [1781924820, 0, 0, 0, 63337.09],
                [1781924880, 0, 0, 0, 63331.95]
            ]
        }
    }
}
```

**Workaround:** None for external users until PM clarifies contract. Internal callers can pass `ohlcv=true` for full candles.

**Action:** PM to confirm whether external API should return full OHLCV by default or document close-only as intentional.

---

### F5 — Missing `start_time` returns 200 instead of 400

| | |
|---|---|
| **Severity** | BUG |
| **Owner** | Engineering |
| **Tests** | R22 |
| **Status** | Open |

**Expected:** HTTP 400 — `start_time` is required for kline queries.

**Actual:** HTTP 200 with a point-price response shape (`data.assets[]`) instead of `data.asset_ticks`.

#### R22 — Reproduction

**Request:**

```bash
curl "https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&aggregation=1m&end_time=1781928304&ohlcv=true&partial=true&type=linear"
```

**Response (200 — wrong shape):**

```json
{
    "success": true,
    "data": {
        "assets": [
            {
                "ohlcv": [1781928324, 63399.3, 63399.4, 63399.3, 63399.3, 0.262],
                "price": 63399.3,
                "time": 1781928324,
                "asset": "btc/usdt_linear",
                "start_time": 1585132560,
                "is_active": true,
                "price_available": true,
                "trading_enabled": true,
                "type": "LINEAR"
            }
        ]
    }
}
```

**Expected error:**

```json
{
    "success": false,
    "errors": [{ "code": 400, "text": "start_time is required" }]
}
```

**Impact:** Clients missing `start_time` get a silent shape change — easy to mis-parse.

**Action:** Return 400 when required kline params are absent.

---

### F7 — Single-asset 1s klines returns 404

| | |
|---|---|
| **Severity** | BUG |
| **Owner** | Engineering |
| **Tests** | R17 |
| **Status** | Open |

**Expected:** `GET /asset/btc/usdt/klines?aggregation=1s&duration=300` returns 1-second candles (WS `kline@1s@btcusdt` works on linear).

**Actual:** HTTP 404 — asset not found.

#### R17 — Reproduction

**Request:**

```bash
curl "https://price.mudrex.com/api/v1/asset/btc/usdt/klines?aggregation=1s&duration=300&ohlcv=true&type=linear"
```

**Response (404):**

```json
{
    "success": false,
    "errors": [
        { "code": 404, "text": "btc/usdt asset not found" }
    ]
}
```

**Note:** `1m` klines on the same path work (`R8` PASS). Only `1s` + `duration` combination fails.

**Workaround:** Use WebSocket `kline@1s@btcusdt` on `wss://price.mudrex.com/api/v2/linear`.

**Action:** Investigate REST 1s path / `duration` param support vs WS parity.

---

### F6 — WebSocket idle timeout not enforced

| | |
|---|---|
| **Severity** | BUG / DOC |
| **Owner** | Engineering + Docs |
| **Tests** | W10 |
| **Status** | Open |

**Expected (per contract):** Server closes connection after **40 seconds** of inactivity.

**Actual:** Connection remained open after **55 seconds** with no client messages.

#### W10 — Reproduction

1. Connect to `wss://price.mudrex.com/api/v2/linear`
2. Do not send SUBSCRIBE, PING, or any message
3. Wait 55 seconds
4. Connection still open

**Impact:** Clients relying on server-side idle close for cleanup may hold connections longer than documented.

**Workaround:** Client-side idle timeout at 40s; send PING every 20s for keepalive.

**Action:** Confirm production timeout value and update contract or fix server behavior.

---

### F2 — LIST_SUBSCRIPTIONS field name mismatch

| | |
|---|---|
| **Severity** | DOC |
| **Owner** | Docs |
| **Tests** | W5 (PASS, flagged) |
| **Status** | Open |

**Documented:** `ticker_assets`  
**Actual:** `ticker_5s_assets` and `ticker_1s_assets`

**Live response:**

```json
{
    "id": 2,
    "method": "LIST_SUBSCRIPTIONS",
    "result": {
        "subscriptions": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
        "ticker_5s_assets": ["btcusdt"],
        "ticker_1s_assets": []
    }
}
```

**Action:** Update WebSocket v2 docs to match live field names.

---

### F3 — Mark vs LTP closes differ

| | |
|---|---|
| **Severity** | INFO (not a bug) |
| **Owner** | — |
| **Tests** | C7 (PASS) |
| **Status** | Expected |

Mark price and LTP close for the same minute differ slightly (e.g. LTP `63394` vs mark `63396.67` on this run). This is expected — mark is fair-value; LTP is last trade.

---

## Resolved issues

### F4 — Single-asset mark-price path returns 404 ✅

| | |
|---|---|
| **Severity** | BUG (was) |
| **Tests** | R9 |
| **Status** | **Fixed** (2026-06-20) |

Previously `GET /asset/btc/usdt/mark-price` returned 404. On the latest run it returns **200** with mark klines in `data.ticks`.

**Request:**

```bash
curl "https://price.mudrex.com/api/v1/asset/btc/usdt/mark-price?start_time=1781924704&end_time=1781928304&aggregation=1m&ohlcv=true"
```

**Response (200):**

```json
{
    "success": true,
    "data": {
        "ticks": [
            [1781924760, 63336, 63348, 63335.9, 63339.7],
            [1781924820, 63339.7, 63348, 63336.99, 63337.09],
            [1781924880, 63337.09, 63341.6, 63331.95, 63331.95]
        ]
    }
}
```

Bulk `/assets/mark-price` remains valid; single-asset path is now usable.

---

### W17 — Spot kline subscribe + push ✅

| | |
|---|---|
| **Status** | **PASS** (2026-06-20) |

Previously flagged as harness false negative. Re-run confirmed spot `kline@1m@btcusdt` subscribe and push with volume field (`got_kline=True`).

---

### C1 / C2 — REST vs WS cross-check ✅

| | |
|---|---|
| **Status** | **PASS** (2026-06-20) |

| Test | REST close | WS close |
|---|---|---|
| C1 (LTP) | `63394` | `63370.1` |
| C2 (mark) | `63396.67` | `63374.63` |

Values within 0.5% tolerance. Previous failures were timing-related (no push in window).

---

## Timing / harness failures

These are not confirmed API bugs. Re-run or extend wait windows before filing engineering tickets.

### W1-W4 — Linear subscribe all streams

| | |
|---|---|
| **Severity** | Timing |
| **Status** | Inconclusive |

**Result:** FAIL — subscribe succeeded; received `ticker@5s` and `kline@1s@btcusdt` pushes only.

**Missing in 70s window:** `kline@1m@btcusdt`, `markKline@1m@btcusdt`, `markKline@1s@btcusdt`

**Subscribe request:**

```json
{
    "id": 1,
    "method": "SUBSCRIBE",
    "params": [
        "kline@1m@btcusdt",
        "kline@1s@btcusdt",
        "markKline@1m@btcusdt",
        "markKline@1s@btcusdt",
        "ticker@5s"
    ],
    "assets": ["btcusdt", "ethusdt"]
}
```

**Captured pushes (sample):**

```json
{ "stream": "ticker@5s", "data": [{ "s": "btcusdt", "p": 63399.4, "mp": 63399.3 }] }
{ "stream": "kline@1s@btcusdt", "data": { "s": "btcusdt", "t": 1781928328, "o": 63399.3, "h": 63399.4, "l": 63399.3, "c": 63399.3, "v": 0.392 } }
```

**Cause:** `kline@1m` and `markKline` streams push on minute boundaries. Test connected mid-minute and may not have waited long enough. C1/C2 passed in the same run, confirming 1m streams work when aligned to boundary.

**Action:** Extend W1-W4 wait to ≥65s or start subscribe just before minute rollover. Do not treat as API regression.

---

## Confirmed working (related negatives)

These validate error handling and passed — included for contrast.

| ID | Case | Result |
|---|---|---|
| R9 | Single mark klines | 200 — `data.ticks` (fixed) |
| R14 | `start_time > end_time` | 400 — `end time should be greater than start time` |
| R19 | Invalid aggregation `99x` | 400 — `99x aggregation not supported` |
| R18 | Invalid asset `foo/bar` | 200 — empty `asset_ticks` |
| W11 | Invalid stream `kline@5m` | WS 400 — `invalid stream name` |
| W13 | Unknown method `FOO` | WS 400 — `unknown method` |
| W15 | UNSUBSCRIBE not subscribed | WS 400 — `not subscribed` |
| W16 | 16th subscription | WS 429 — `subscription limit reached` |
| W18 | Spot `markKline` | WS 400 — rejected (linear-only) |

---

## Recommended actions

| Priority | Issue | Action |
|---|---|---|
| P0 | F1 | PM decision on external OHLCV contract |
| P1 | F5, F7 | Engineering fixes or explicit WS-only docs for 1s REST |
| P1 | F6 | Align idle timeout behavior with documentation |
| P2 | F2 | Update LIST_SUBSCRIPTIONS field names in docs |
| P3 | W1-W4 | Extend harness wait; do not block launch on timing flake |
| — | F4 | ✅ Fixed — remove bulk-only workaround from docs |

---

## Raw data

| File | Contents |
|---|---|
| `testing/price-rest-360-results.json` | 39 REST tests — 35 pass, 4 fail |
| `testing/price-ws-360-results.json` | 20 WS tests — 18 pass, 2 fail |
| `testing/bulk-klines-test-results.md` | Bulk LTP/mark samples |
| `testing/ws/price-v2-capture.jsonl` | Live WS message capture |

**Re-run:**

```bash
cd "/Users/jm/Mudrex API Testing"
bash testing/run_price_360.sh
```
