# Mark Price, LTP Klines & Price WebSocket — Test Report

**Test date:** 2026-06-17  
**Trading API key:** Verified (`GET /fapi/v1/futures/funds?trade_currency=INR` → 200)  
**Price service auth:** Not required for tested endpoints

---

## Summary

| # | Test | Result | HTTP | Notes |
|---|---|---|---|---|
| 1 | Bulk LTP klines (full params) | **PASS** | 200 | 59 candles, 6 fields each |
| 2 | Bulk mark klines (full params) | **PASS** | 200 | 59 candles, 5 fields each |
| 3 | Bulk LTP — external params only | **PASS** | 200 | See finding F1 — OHLC zeros without `ohlcv` |
| 4 | Bulk mark — external params only | **PASS** | 200 | See finding F1 |
| 5 | Last price LTP | **PASS** | 200 | `64864.9` at `1781691300` |
| 6 | WS v2 linear — SUBSCRIBE | **PASS** | — | `result: success` |
| 7 | WS v2 — `kline@1m@btcusdt` | **PASS** | — | OHLCV push received |
| 8 | WS v2 — `markKline@1m@btcusdt` | **PASS** | — | OHLC push, no volume |
| 9 | WS v2 — `ticker@5s` | **PASS** | — | Snapshot + 5s updates with `p` and `mp` |
| 10 | WS v2 — LIST_SUBSCRIPTIONS | **PASS** | — | See finding F2 — field name differs from doc |
| 11 | WS v2 — ping keepalive | **PASS** | — | Connection held 35s |

**Score: 11/11 PASS**

---

## Finding F1 — External params without `ohlcv`

PM said external users get only: `assets`, `aggregation`, `start_time`, `end_time`.

Calling with **only those four params** returns `200` but candles have **`o,h,l = 0`** — close appears at index 4:

```
GET /api/v1/assets/price?assets=btc/usdt&aggregation=1m&start_time=...&end_time=...
→ [1781691300, 0, 0, 0, 64892.5, 0]
```

**Question for engineering:** Should external users pass `ohlcv=true` implicitly, or is close-only in tick array the intended external shape?

---

## Finding F2 — LIST_SUBSCRIPTIONS field name

Doc says `ticker_assets`. Live response uses:

```json
{
  "subscriptions": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
  "ticker_5s_assets": ["btcusdt"],
  "ticker_1s_assets": []
}
```

Update docs to match live API.

---

## Finding F3 — Mark vs LTP divergence (expected)

Same 1h window — mark and LTP closes differ slightly (e.g. LTP close `64858` vs mark close `64858.62` at `1781691240`). Confirms separate feeds.

WS ticker at same time: `p: 64864.9`, `mp: 64864.9` — aligned at snapshot.

---

## 1. Bulk LTP klines — PASS

```bash
curl -X GET "https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time=1781687751&end_time=1781691351&partial=true&type=linear"
```

**Response (last candle):**

```json
[1781691240, 64869.9, 64869.9, 64828.7, 64858, 19.683]
```

Format: `[open_time, open, high, low, close, volume]`

Full capture: `testing/bulk-klines-test-results.md`

---

## 2. Bulk mark klines — PASS

```bash
curl -X GET "https://price.mudrex.com/api/v1/assets/mark-price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time=1781687751&end_time=1781691351&partial=true&type=linear"
```

**Response (last candle):**

```json
[1781691240, 64873.02, 64873.02, 64834.11, 64858.62]
```

Format: `[open_time, open, high, low, close]` — no volume

---

## 3. Last price — PASS

```bash
curl -X GET "https://price.mudrex.com/api/v1/asset/btc/usdt/last-price?type=linear"
```

```json
{
    "success": true,
    "data": {
        "price": 64864.9,
        "time": 1781691300,
        "asset": "btc/usdt_linear",
        "type": "LINEAR",
        "price_available": true,
        "trading_enabled": true
    }
}
```

---

## 4. WebSocket v2 linear — PASS

**URL:** `wss://price.mudrex.com/api/v2/linear`

**Subscribe:**

```json
{
  "id": 1,
  "method": "SUBSCRIBE",
  "params": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
  "assets": ["btcusdt"]
}
```

**Subscribe response:**

```json
{ "method": "SUBSCRIBE", "id": 1, "result": "success" }
```

**Ticker snapshot (immediate):**

```json
{
  "stream": "ticker@5s",
  "data": [{ "s": "btcusdt", "p": 64863.6, "mp": 64862 }]
}
```

**Mark kline push:**

```json
{
  "stream": "markKline@1m@btcusdt",
  "data": {
    "s": "btcusdt",
    "t": 1781691300,
    "o": 64858.62,
    "h": 64864.9,
    "l": 64837.09,
    "c": 64864.8
  }
}
```

**LTP kline push:**

```json
{
  "stream": "kline@1m@btcusdt",
  "data": {
    "s": "btcusdt",
    "t": 1781691300,
    "o": 64858,
    "h": 64864.9,
    "l": 64834.1,
    "c": 64864.9,
    "v": 10.921
  }
}
```

Full capture: `testing/ws/price-v2-capture.jsonl`

---

## Raw result files

| File | Contents |
|---|---|
| `testing/bulk-klines-test-results.md` | Bulk LTP + mark REST (1h window) |
| `testing/ws/price-v2-capture.jsonl` | WS v2 message log |

---

## Next tests to run

- [ ] Invalid stream name (400 all-or-nothing)
- [ ] 16th subscription (429 limit)
- [ ] WS spot endpoint `/api/v2/spot`
- [ ] Multi-asset bulk `assets=btc/usdt,eth/usdt`
- [ ] `aggregation=1s` REST and WS
- [ ] Cross-check REST bulk close vs WS kline close for same minute
