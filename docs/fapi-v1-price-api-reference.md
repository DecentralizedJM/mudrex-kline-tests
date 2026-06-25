# Mudrex FAPI v1 Price API Reference

## 1. Objective

This document is the public API reference for Mudrex market-data endpoints exposed for API trading. It covers:

- **Historical Kline (price):** Bulk fetch of price klines over REST.
- **Historical Mark Kline (mark price):** Bulk fetch of mark-price klines over REST.
- **Live kline streaming:** Real-time price and mark-price klines updates over WebSocket.

All endpoints are public and require no authentication. They are read-only market-data endpoints.

---

## 2. General Conventions

These conventions apply across the API. Endpoint-specific request parameters, response schemas, symbol formats, and supported intervals are documented per endpoint in Sections 3 and 4.

### 2.1 Base URL and Versioning

| Surface | Base URL |
|---------|----------|
| **REST** | `https://trade.mudrex.com/fapi/v1/price` |
| **WebSocket** | `wss://trade.mudrex.com/fapi/v1/price/ws/linear` |

The API is versioned in the path (`/fapi/v1/`). Breaking changes will be introduced under a new version segment; additive, backward-compatible changes may be made within a version.

### 2.2 Access Model

All endpoints are **public**. No API key, signature, or authentication header is required. Do not send credentials.

### 2.3 Timestamps and Numbers

- Timestamps are epoch seconds in UTC (integer).
- Price and volume values are JSON numbers (floating point).

---

## 3. REST Endpoints - Market Data

**Per-endpoint template:** Every entry below follows the same shape: Purpose · Method & path · Request · Response · Example.

All REST endpoints are `GET` requests with URL query parameters (case-sensitive) and return JSON (`Content-Type: application/json`).

### 3.1 Historical Kline

**Purpose:** Bulk historical klines for a trading pair.  
**Method & path:** `GET /fapi/v1/price/kline`

**Request parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `assets` | string | Yes | - | Comma-separated trading pairs in `<base>/<quote>` format, e.g. `BTC/USDT,ETH/USDT`. Maximum 25 symbols per request. A literal `/` is accepted, no percent-encoding required. |
| `aggregation` | enum | Yes | `1m` | Kline interval. One of: `1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth`. |
| `start_time` | number | Yes | - | Epoch seconds, inclusive. |
| `end_time` | number | Yes | - | Epoch seconds, inclusive. |

**Response:** 
A JSON envelope. `data.asset_ticks` is a map keyed by symbol; each value is an array of candles ordered ascending by open time. Each candle is a 6-element array.

| Field | Type | Notes |
|-------|------|-------|
| `success` | boolean | `true` on success. |
| `data.asset_ticks` | object | Map of symbol → array of candle arrays. Keys are lowercase, e.g. `btc/usdt`. |

**Limits:**
- Single call returns a maximum of 1440 klines per asset.
- Invalid symbols or symbols where klines are not found for the time interval are omitted from the response.

**Klines array layout:**

| Index | Field | Type | Notes |
|-------|-------|------|-------|
| 0 | Open time | number | Epoch seconds, UTC |
| 1 | Open | number | |
| 2 | High | number | |
| 3 | Low | number | |
| 4 | Close | number | |
| 5 | Volume | number | |

**Example:**
```http
GET https://trade.mudrex.com/fapi/v1/price/kline?assets=BTC/USDT,ETH/USDT&aggregation=1m&start_time=1680312600&end_time=1680312660
```

**Response:**
```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1680312600, 28436.6, 28449.81, 28436.6, 28449.81, 0.742521]
            ],
            "eth/usdt": [
                [1680312600, 1812.4, 1813.9, 1811.0, 1813.2, 15.20831]
            ]
        }
    }
}
```
*Note: Response symbol keys are lowercase (`btc/usdt`) regardless of request casing.*

### 3.2 Mark Price Kline OHLCV

**Purpose:** Bulk historical mark-price candlesticks for a trading pair.  
**Method & path:** `GET /fapi/v1/price/mark-kline`

**Request parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `assets` | string | Yes | - | Comma-separated trading pairs in `<base>/<quote>` format, e.g. `BTC/USDT,ETH/USDT`. Maximum 25 symbols per request. A literal `/` is accepted, no percent-encoding required. |
| `aggregation` | enum | Yes | `1m` | Candle interval. One of: `1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth`. |
| `start_time` | number | Yes | - | Epoch seconds, inclusive. |
| `end_time` | number | Yes | - | Epoch seconds, inclusive. |

**Response:** 
A JSON envelope. `data.asset_ticks` is a map keyed by symbol; each value is an array of candles ordered ascending by open time. Each candle is a 5-element array (no volume).

| Field | Type | Notes |
|-------|------|-------|
| `success` | boolean | `true` on success. |
| `data.asset_ticks` | object | Map of symbol → array of candle arrays. Keys are lowercase, e.g. `btc/usdt`. |

**Limits:**
- Single call returns a maximum of 1440 klines per asset.
- Invalid symbols or symbols where klines are not found for the time interval are omitted from the response.

**Klines array layout:**

| Index | Field | Type | Notes |
|-------|-------|------|-------|
| 0 | Open time | number | Epoch seconds, UTC |
| 1 | Open | number | |
| 2 | High | number | |
| 3 | Low | number | |
| 4 | Close | number | |

**Example:**
```http
GET https://trade.mudrex.com/fapi/v1/price/mark-kline?assets=BTC/USDT&aggregation=1m&start_time=1680312600&end_time=1680312660
```

**Response:**
```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1680312600, 28440.0, 28452.0, 28433.0, 28448.0]
            ]
        }
    }
}
```
*Note: Response symbol keys are lowercase (`btc/usdt`) regardless of request casing.*

---

## 4. WebSocket Streams

**Source:** This section is derived from the [CDaaS] [WebSocket V2] Rules of Engagement document, which is the authoritative specification for the WebSocket protocol. Refer to it for any detail not covered here.

Symbols use a lowercase, no-slash format, e.g. `btcusdt`, `ethusdt`, `solusdt`, `xrpusdt` - this differs from the `<base>/<quote>` format used by the REST endpoints.

### 4.1 Connection

**Endpoint:** `wss://trade.mudrex.com/fapi/v1/price/ws/linear`

Connect with a standard WebSocket upgrade. No authentication required.

### 4.2 Keepalive

The server closes the connection after 40 seconds of inactivity. Any message sent by the client — a `PING` frame, `SUBSCRIBE`, `UNSUBSCRIBE`, or `LIST_SUBSCRIPTIONS` — resets the inactivity timer. Sending regular `PING` frames is the recommended way to keep an idle connection open.

**Recommended ping interval:** 20 seconds.

Subscriptions are per-connection and are not persisted. If the connection drops, re-subscribe to all streams after reconnecting.

### 4.3 Request Format

All client messages share the same envelope:

```json
{
    "id": 1,
    "method": "SUBSCRIBE",
    "params": ["kline@1m@btcusdt"],
    "assets": ["btcusdt"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Correlation ID; the server echoes it back so you can match responses to requests. |
| `method` | string | `SUBSCRIBE`, `UNSUBSCRIBE`, or `LIST_SUBSCRIPTIONS`. |
| `params` | string[] | Stream names to act on. |
| `assets` | string[] | Asset symbols. Applied only when a ticker stream (`ticker@5s` / `ticker@1s`) is present in `params`; ignored for all other streams. |

Mixing stream types in one `params` array is valid. All-or-nothing: if any stream in `params` is invalid, the entire request is rejected and no state changes.

### 4.4 Response Format

Every request receives a response before any stream data is pushed.

**Success:**
```json
{ "method": "SUBSCRIBE", "id": 1, "result": "success" }
```

**Error:**
```json
{ "method": "SUBSCRIBE", "id": 1, "error": { "code": 400, "msg": "invalid stream name: kline@5m@btcusdt" } }
```

### 4.5 Available Streams

| Stream | Name format | Notes |
|--------|-------------|-------|
| Kline 1-second | `kline@1s@<symbol>` | OHLCV candle |
| Kline 1-minute | `kline@1m@<symbol>` | OHLCV candle |
| Mark Kline 1-second | `markKline@1s@<symbol>` | OHLC, no volume |
| Mark Kline 1-minute | `markKline@1m@<symbol>` | OHLC, no volume |
| Ticker 1-second | `ticker@1s` | Changed prices every 1 second |
| Ticker 5-second | `ticker@5s` | Changed prices every 5 seconds |

`ticker@1s` shares all `ticker@5s` semantics: assets supplied in `assets`, a one-time snapshot on subscribe, push only when a tracked asset's price changes within the window, and it counts as a single subscription regardless of asset count.

### 4.6 Subscribe

**Klines:**
```json
{
    "id": 1,
    "method": "SUBSCRIBE",
    "params": ["kline@1m@btcusdt", "kline@1s@ethusdt"]
}
```

**Mark Klines (linear only):**
```json
{
    "id": 2,
    "method": "SUBSCRIBE",
    "params": ["markKline@1m@btcusdt"]
}
```

**Ticker:** The stream name goes in `params` and asset symbols go in `assets`:
```json
{
    "id": 3,
    "method": "SUBSCRIBE",
    "params": ["ticker@5s"],
    "assets": ["btcusdt", "ethusdt"]
}
```

*On a successful ticker subscribe, the server immediately sends a one-time snapshot with the last known ticker for each newly-added asset, so you don't need to wait up to 5 seconds for the first push. Assets with no data yet are omitted from the snapshot.*

### 4.7 Unsubscribe

**Klines:**
```json
{
    "id": 4,
    "method": "UNSUBSCRIBE",
    "params": ["kline@1m@btcusdt"]
}
```

**Ticker:** pass the assets to remove in `assets`. The ticker stream is automatically removed when no assets remain:
```json
{
    "id": 5,
    "method": "UNSUBSCRIBE",
    "params": ["ticker@5s"],
    "assets": ["btcusdt"]
}
```

### 4.8 List Subscriptions

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
        "subscriptions": ["kline@1m@btcusdt", "ticker@5s"],
        "ticker_5s_assets": ["btcusdt", "ethusdt"],
        "ticker_1s_assets": ["solusdt"]
    }
}
```

### 4.9 Push Data Formats

All server-initiated pushes use this envelope:

```json
{ "stream": "<stream-name>", "data": <payload> }
```

**Kline:** Stream `kline@1m@btcusdt`:
```json
{
    "stream": "kline@1m@btcusdt",
    "data": {
        "s": "btcusdt",
        "t": 1748736060,
        "o": 67000.0,
        "h": 67500.0,
        "l": 66800.0,
        "c": 67200.0,
        "v": 12.5
    }
}
```

| Field | Description |
|-------|-------------|
| `s` | Symbol |
| `t` | Candle open time (Unix seconds) |
| `o` | Open |
| `h` | High |
| `l` | Low |
| `c` | Close |
| `v` | Volume |

**Mark Kline (linear only):** Stream `markKline@1m@btcusdt`. Same envelope as kline; data has no `v` field:
```json
{
    "stream": "markKline@1m@btcusdt",
    "data": {
        "s": "btcusdt",
        "t": 1748736060,
        "o": 67010.0,
        "h": 67510.0,
        "l": 66810.0,
        "c": 67215.0
    }
}
```

**Ticker:** Stream `ticker@5s` (and `ticker@1s`):
```json
{
    "stream": "ticker@5s",
    "data": [
        { "s": "btcusdt", "p": 67200.0, "mp": 67210.0 },
        { "s": "ethusdt", "p": 3500.0 }
    ]
}
```

| Field | Description |
|-------|-------------|
| `s` | Symbol |
| `p` | Last price |
| `mp` | Mark price (linear endpoint only; field omitted when unavailable) |

*Only assets whose price changed since the previous window are included in each push. If no subscribed asset changed, no message is sent.*

---

## 5. Rate Limits & Quotas

Rate limiting is per-minute call limiting for REST (no weight-based scheme). REST and WebSocket limits are tracked independently.

### 5.1 REST

| Limit | Value | Scope |
|-------|-------|-------|
| Requests per minute | 300 | Per IP |

On exceeding the limit, the server responds with HTTP `429 Too Many Requests`.

### 5.2 WebSocket

**Max active subscriptions per connection:** 15.

- A ticker stream (`ticker@5s` / `ticker@1s`) counts as 1 subscription regardless of how many assets are tracked.
- Ticker asset count is unlimited and does not contribute to the cap.
- Exceeding the cap returns application error `429 subscription limit reached`.

The new websocket creation has a rate limit as following:

| Limit | Value | Scope |
|-------|-------|-------|
| Requests per minute | 10 | Per IP |

On exceeding the limit, the server responds with HTTP `429 Too Many Requests`.

---

## 6. Errors & Status Codes

### 6.1 REST

Error responses mirror the success envelope with `success: false`:

```json
{ "success": false, "error": { "code": 123, "message": "Invalid symbol." } }
```

| HTTP status | Code | Text |
|-------------|------|------|
| 400 | 400 | `assets are required` <br> `allowed assets size is 25` <br> `aggregation not supported` <br> `start and end time should be greater than 0` <br> `end time should be greater than start time` <br> `invalid assets` |
| 404 | 404 | `asset not found` |
| 429 | 429 | `Rate limit exceeded` |
| 5xx | 500 | `something went wrong` |

### 6.2 WebSocket

Errors are returned in the response error object. Codes are application-level, not HTTP status codes.

| Code | Message | Cause |
|------|---------|-------|
| 400 | `invalid JSON` | Malformed request body |
| 400 | `unknown method` | `method` is not one of the three valid values |
| 400 | `invalid stream name: <x>` | Unrecognised stream or unsupported interval |
| 400 | `not subscribed: <x>` | Unsubscribing from a stream not currently active |
| 429 | `subscription limit reached` | Would exceed 15 active subscriptions |
