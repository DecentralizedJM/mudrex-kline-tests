# Data Read Client — Dev / PM Context Log

**Last updated:** 2026-06-15 (from engineering thread)

---

## Timeline & availability

| Milestone | ETA / status |
|---|---|
| Params & response details from dev | EOD tomorrow (from thread date) |
| Base URL & rate limits consensus | Tuesday 16 June |
| Final go-live ETA | End of next week (TBC after 16 June) |
| SANDBOX push | Expected same day as thread |
| PRODUCTION push | Expected coming Monday (from thread) |

**Thread note (Sanket):** Endpoints **not yet on SANDBOX or PRODUCTION** at time of message; push to SANDBOX expected that day, PROD by Monday.

**Thread note (Akshat):** Can test using `price.mudrex.com` base URL. **Mark price not live on PROD yet**; LTP klines params/responses behave similarly.

---

## Rate limits

> "There is no rate limit right now. So be careful 😅 But yeah, you can test it out."

Treat as **no enforced limit currently** — still test responsibly. Final limits TBD after 16 June consensus.

---

## External vs internal params

Bulk klines (LTP and mark) — **external users only get:**

| Param | Description |
|---|---|
| `assets` | Asset pair(s), e.g. `btc/usdt` |
| `aggregation` | Kline interval, e.g. `1m` |
| `start_time` | Unix seconds, inclusive |
| `end_time` | Unix seconds, inclusive |

Internal-only params (may appear in dev examples but not for external docs): `ohlcv`, `partial`, `type`, `exchange`, etc. — confirm with PM before documenting externally.

---

## Bulk LTP klines

**Path:**

```
GET https://price.mudrex.com/api/v1/assets/price
```

**Example (full internal param set from dev):**

```
https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time=1781172000&end_time=1781172300&partial=true&type=linear
```

**Response:**

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781172000, 62899.6, 62929.2, 62896, 62919.3, 67.4],
                [1781172060, 62919.3, 62937.8, 62894.2, 62908.1, 14.605],
                [1781172120, 62908.1, 62921.8, 62864, 62864, 13.957],
                [1781172180, 62864, 62870.3, 62854, 62857.9, 20.122],
                [1781172240, 62857.9, 62870.1, 62814.1, 62830.6, 24.896],
                [1781172300, 62830.6, 62856.4, 62827.1, 62853.9, 30.27]
            ]
        }
    }
}
```

**Candle array format (LTP — 6 fields):**

| Index | Field |
|---|---|
| 0 | Open time (Unix seconds) |
| 1 | Open |
| 2 | High |
| 3 | Low |
| 4 | Close |
| 5 | Volume |

---

## Bulk mark price klines

**Path:**

```
GET https://price.mudrex.com/api/v1/assets/mark-price
```

**Example:**

```
https://price.mudrex.com/api/v1/assets/mark-price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time=1781172000&end_time=1781172300&partial=true&type=linear
```

**Same params and response structure as LTP bulk endpoint** (per dev). Not yet on PROD at time of thread; sandbox sample below.

**Response (sandbox sample from dev):**

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781172000, 62897.09, 62929.2, 62897.09, 62919.3],
                [1781172060, 62919.3, 62937.8, 62898.21, 62908.1],
                [1781172120, 62908.1, 62921.8, 62868.88, 62868.88],
                [1781172180, 62868.88, 62871.48, 62854.86, 62854.91],
                [1781172240, 62854.91, 62870.1, 62816.7, 62828.8],
                [1781172300, 62828.8, 62856.4, 62828.8, 62856.3]
            ]
        }
    }
}
```

**Candle array format (mark — 5 fields, no volume):**

| Index | Field |
|---|---|
| 0 | Open time (Unix seconds) |
| 1 | Open |
| 2 | High |
| 3 | Low |
| 4 | Close |

---

## Asset identifier format

REST bulk endpoints use **`btc/usdt`** (lowercase, slash-separated).

WebSocket v2 uses **`btcusdt`** (lowercase, no slash).

Do not mix formats across APIs.

---

## Open items (awaiting engineering)

- [ ] Final external param list confirmed by PM
- [ ] Base URL consensus (16 June)
- [ ] Rate limit policy (16 June)
- [ ] Mark price live on prod
- [ ] SANDBOX URL if different from `price.staging.mudrex.com`
- [ ] Error response shapes for invalid assets / time ranges
- [ ] Multi-asset bulk: comma-separated `assets` format TBD

---

## Testing status

| Endpoint | Prod | Notes |
|---|---|---|
| Bulk LTP klines `/assets/price` | **Live** | 360° tested 2026-06-17 |
| Bulk mark klines `/assets/mark-price` | **Live** | 360° tested 2026-06-17 |
| Single LTP `/asset/.../klines` | **Live** | Returns `ticks` array |
| Single mark `/asset/.../mark-price` | **404** | BUG F4 — use bulk path |
| WS v2 linear | **Live** | 16/20 pass in 360° sweep |
| WS v2 spot | **Live** | kline + ticker work |
| WS v1 legacy | **Alive** | Probe only |

**360° report:** `Mark_Price_LTP_360_Test_Report.md`
