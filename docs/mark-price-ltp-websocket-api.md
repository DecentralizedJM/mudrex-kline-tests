# Mark Price, LTP Klines & Price WebSocket — API Reference

**Base URL (REST):** `https://price.mudrex.com/api/v1`  
**WebSocket v2:** `wss://price.mudrex.com/api/v2/linear` (futures) · `wss://price.mudrex.com/api/v2/spot` (spot)  
**Auth:** None required  
**Tested:** Production, 2026-06-17

Prices are USDT-denominated. **LTP** = last traded price. **Mark price** = fair-value reference used for PnL and liquidation.

**Asset formats:**
- REST: `btc/usdt` (lowercase, slash)
- WebSocket: `btcusdt` (lowercase, no slash)

---

## REST — Bulk LTP klines

`GET /assets/price`

Returns OHLCV candle history based on **last traded price**.

### Request (query parameters)

**External users (PM-approved):**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `assets` | string | Yes | Asset pair, e.g. `btc/usdt`. Comma-separated for multiple. |
| `aggregation` | string | Yes | Candle interval. LINEAR: `1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth` |
| `start_time` | int | Yes | Unix seconds, inclusive |
| `end_time` | int | Yes | Unix seconds, inclusive |

**Additional params (internal / full access):**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ohlcv` | bool | No | `true` for full OHLCV candles. Without it, returns close-only ticks (see note below). |
| `type` | string | No | `linear` (futures) or `spot`. Default `spot`. |
| `partial` | bool | No | Best-effort for bulk multi-asset requests |

### cURL

```bash
curl -X GET "https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&aggregation=1m&start_time=1781691017&end_time=1781694617&ohlcv=true&partial=true&type=linear"
```

### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781691060, 64843.3, 64877.4, 64831.5, 64874.2, 14.562],
                [1781691120, 64874.2, 64885.8, 64863.9, 64871.3, 15.54],
                [1781691180, 64871.3, 64873.8, 64867.3, 64869.9, 9.43]
            ]
        }
    }
}
```

### Response fields — candle array (LTP)

Each candle is an array of **6** values:

| Index | Field | Description |
|---|---|---|
| 0 | `open_time` | Candle open time (Unix seconds) |
| 1 | `open` | Open price (USDT) |
| 2 | `high` | High price (USDT) |
| 3 | `low` | Low price (USDT) |
| 4 | `close` | Close price (USDT) |
| 5 | `volume` | Volume |

### Response — external params only (no `ohlcv`)

When only the four external params are passed, HTTP 200 is returned but OHLCV fields are zero — close appears at index 4:

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781691300, 0, 0, 0, 64892.5, 0]
            ]
        }
    }
}
```

> **Open question for PM:** Confirm whether external users should receive full OHLCV implicitly or this close-only shape.

### Errors

| HTTP | Condition | Response |
|---|---|---|
| 400 | `start_time > end_time` | `{"success":false,"errors":[{"code":400,"text":"end time should be greater than start time"}]}` |
| 400 | Invalid aggregation | `{"success":false,"errors":[{"code":400,"text":"99x aggregation not supported"}]}` |
| 200 | Future `end_time` | `{"success":true,"data":{"asset_ticks":{"btc/usdt":[]}}}` |
| 200 | Invalid asset | `{"success":true,"data":{"asset_ticks":{}}}` (empty) |
| 200 | Missing `start_time` | Returns point-price shape instead of 400 — see bug note below |

---

## REST — Bulk mark price klines

`GET /assets/mark-price`

Same request parameters and response structure as bulk LTP klines. Candles use **mark price** (5 fields, no volume).

### cURL

```bash
curl -X GET "https://price.mudrex.com/api/v1/assets/mark-price?assets=btc/usdt&aggregation=1m&start_time=1781691017&end_time=1781694617&ohlcv=true&partial=true&type=linear"
```

### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781691060, 64843.5, 64877.4, 64831.5, 64874.0],
                [1781691120, 64874.0, 64885.8, 64868.2, 64871.5],
                [1781691180, 64871.5, 64873.8, 64872.7, 64873.0]
            ]
        }
    }
}
```

### Response fields — candle array (mark)

Each candle is an array of **5** values:

| Index | Field | Description |
|---|---|---|
| 0 | `open_time` | Candle open time (Unix seconds) |
| 1 | `open` | Mark open (USDT) |
| 2 | `high` | Mark high (USDT) |
| 3 | `low` | Mark low (USDT) |
| 4 | `close` | Mark close (USDT) |

Mark and LTP closes differ slightly for the same minute (expected).

---

## REST — Single-asset LTP klines

`GET /asset/:base/:quote/klines`

### Request (query parameters)

| Parameter | Type | Required | Description |
|---|---|---|---|
| `start_time` | int | Yes | Unix seconds, inclusive |
| `end_time` | int | Yes | Unix seconds, inclusive |
| `aggregation` | string | Yes | e.g. `1m` |
| `ohlcv` | bool | No | `true` for candles |
| `type` | string | No | `linear` or `spot` |

### cURL

```bash
curl -X GET "https://price.mudrex.com/api/v1/asset/btc/usdt/klines?start_time=1781691017&end_time=1781694617&aggregation=1m&ohlcv=true&type=linear"
```

### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "ticks": [
            [1781691060, 64843.3, 64877.4, 64831.5, 64874.2, 14.562],
            [1781691120, 64874.2, 64885.8, 64863.9, 64871.3, 15.54]
        ]
    }
}
```

> Single-asset path returns `data.ticks` (not `asset_ticks`). Bulk path returns `data.asset_ticks`. Last candle close matches bulk for the same window.

### Errors

| HTTP | Condition | Response |
|---|---|---|
| 404 | 1s klines | `{"success":false,"errors":[{"code":404,"text":"btc/usdt asset not found"}]}` |

---

## REST — Last price (LTP)

`GET /asset/:base/:quote/last-price`

### Request

| Parameter | Type | Required | Description |
|---|---|---|---|
| `type` | string | No | `linear` or `spot` |

### cURL

```bash
curl -X GET "https://price.mudrex.com/api/v1/asset/btc/usdt/last-price?type=linear"
```

### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "price": 64644,
        "time": 1781694617,
        "asset": "btc/usdt_linear",
        "start_time": 1585132560,
        "is_active": true,
        "price_available": true,
        "trading_enabled": true,
        "type": "LINEAR"
    }
}
```

---

## REST — Point price (no klines)

`GET /asset/:base/:quote/price`

Returns current price without OHLCV history.

### cURL

```bash
curl -X GET "https://price.mudrex.com/api/v1/asset/btc/usdt/price?type=linear"
```

### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "price": 64660,
        "time": 1781694621,
        "asset": "btc/usdt_linear",
        "start_time": 1585132560,
        "is_active": true,
        "price_available": true,
        "trading_enabled": true,
        "type": "LINEAR"
    }
}
```

---

## WebSocket v2 — Overview

| Market | URL |
|---|---|
| Linear (futures) | `wss://price.mudrex.com/api/v2/linear` |
| Spot | `wss://price.mudrex.com/api/v2/spot` |

- No authentication
- Server closes connection after **40 seconds** of inactivity
- Recommended: send PING every **20 seconds**
- Subscriptions are per-connection — re-subscribe after reconnect
- Max **15** active subscriptions per connection (`ticker@5s` counts as 1)

---

## WebSocket v2 — Request format

All client messages use the same JSON envelope:

```json
{
    "id": 1,
    "method": "SUBSCRIBE",
    "params": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
    "assets": ["btcusdt"]
}
```

| Field | Type | Description |
|---|---|---|
| `id` | int | Correlation ID — echoed in responses |
| `method` | string | `SUBSCRIBE`, `UNSUBSCRIBE`, or `LIST_SUBSCRIPTIONS` |
| `params` | string[] | Stream names |
| `assets` | string[] | Only used when `ticker@5s` is in `params`; ignored otherwise |

### Available streams

| Stream | Format | Endpoints | Notes |
|---|---|---|---|
| Kline 1s | `kline@1s@<symbol>` | spot, linear | OHLCV |
| Kline 1m | `kline@1m@<symbol>` | spot, linear | OHLCV |
| Mark kline 1s | `markKline@1s@<symbol>` | **linear only** | OHLC, no volume |
| Mark kline 1m | `markKline@1m@<symbol>` | **linear only** | OHLC, no volume |
| Ticker | `ticker@5s` | spot, linear | Changed prices every 5s |

---

## WebSocket v2 — SUBSCRIBE

### Klines (linear)

**Request:**

```json
{
    "id": 1,
    "method": "SUBSCRIBE",
    "params": ["kline@1m@btcusdt", "kline@1s@btcusdt"]
}
```

**Response:**

```json
{
    "method": "SUBSCRIBE",
    "id": 1,
    "result": "success"
}
```

### Mark klines (linear only)

**Request:**

```json
{
    "id": 2,
    "method": "SUBSCRIBE",
    "params": ["markKline@1m@btcusdt"]
}
```

### Ticker

**Request:**

```json
{
    "id": 3,
    "method": "SUBSCRIBE",
    "params": ["ticker@5s"],
    "assets": ["btcusdt", "ethusdt"]
}
```

On success, server immediately sends a snapshot of last known tickers for newly-added assets.

---

## WebSocket v2 — Push data

All server pushes use:

```json
{ "stream": "<stream-name>", "data": <payload> }
```

### Kline push

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

| Field | Description |
|---|---|
| `s` | Symbol |
| `t` | Candle open time (Unix seconds) |
| `o` | Open |
| `h` | High |
| `l` | Low |
| `c` | Close |
| `v` | Volume |

### Mark kline push (linear only)

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

No `v` field on mark klines.

### Ticker push (linear)

```json
{
    "stream": "ticker@5s",
    "data": [
        { "s": "btcusdt", "p": 64864.9, "mp": 64864.9 }
    ]
}
```

| Field | Description |
|---|---|
| `s` | Symbol |
| `p` | Last price (LTP) |
| `mp` | Mark price — **linear endpoint only** |

On **spot** endpoint, `mp` is omitted.

Only assets whose price changed in the 5-second window are included.

---

## WebSocket v2 — UNSUBSCRIBE

### Kline

```json
{
    "id": 4,
    "method": "UNSUBSCRIBE",
    "params": ["kline@1m@btcusdt"]
}
```

### Ticker

```json
{
    "id": 5,
    "method": "UNSUBSCRIBE",
    "params": ["ticker@5s"],
    "assets": ["btcusdt"]
}
```

`ticker@5s` is removed automatically when no assets remain.

---

## WebSocket v2 — LIST_SUBSCRIPTIONS

**Request:**

```json
{
    "id": 6,
    "method": "LIST_SUBSCRIPTIONS"
}
```

**Response:**

```json
{
    "id": 6,
    "method": "LIST_SUBSCRIPTIONS",
    "result": {
        "subscriptions": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
        "ticker_5s_assets": ["btcusdt"],
        "ticker_1s_assets": []
    }
}
```

---

## WebSocket v2 — Errors

Every request receives a response before stream data is pushed. Errors use application-level codes (not HTTP).

### Success

```json
{ "method": "SUBSCRIBE", "id": 1, "result": "success" }
```

### Error responses (live samples)

| Code | Message | Cause |
|---|---|---|
| 400 | `invalid stream name: kline@5m@btcusdt` | Unsupported interval in stream name |
| 400 | `invalid stream name: markKline@1m@btcusdt` | Mark kline on spot endpoint |
| 400 | `unknown method` | `method` not SUBSCRIBE / UNSUBSCRIBE / LIST_SUBSCRIPTIONS |
| 400 | `invalid JSON` | Malformed request body |
| 400 | `not subscribed: kline@1m@btcusdt` | UNSUBSCRIBE from inactive stream |
| 429 | `subscription limit reached` | More than 15 active subscriptions |

**Invalid stream example:**

```json
{
    "method": "SUBSCRIBE",
    "id": 1,
    "error": {
        "code": 400,
        "msg": "invalid stream name: kline@5m@btcusdt"
    }
}
```

**Subscription limit example:**

```json
{
    "method": "SUBSCRIBE",
    "id": 16,
    "error": {
        "code": 429,
        "msg": "subscription limit reached"
    }
}
```

**All-or-nothing rule:** If any stream in `params` is invalid, the entire request is rejected and no subscriptions change.

---

## Known issues (from 360° testing — 2026-06-20)

| ID | Issue | Status |
|---|---|---|
| F1 | External 4 params without `ohlcv` → zeros except close | Open — PM to confirm contract |
| F2 | `LIST_SUBSCRIPTIONS` uses `ticker_5s_assets` not `ticker_assets` | Open — update docs |
| F4 | `GET /asset/.../mark-price` returned 404 | **Fixed** (R9 pass) |
| F5 | Missing `start_time` returns 200 instead of 400 | Open — engineering fix |
| F6 | WS idle timeout not enforced within 55s | Open — engineering / docs |
| F7 | Single-asset 1s klines returns 404 | Open — use WS `kline@1s` |

Full test report: [`Mark_Price_LTP_360_Test_Report.md`](../Mark_Price_LTP_360_Test_Report.md)  
Failures only: [`mark-price-ltp-failures.md`](mark-price-ltp-failures.md)
