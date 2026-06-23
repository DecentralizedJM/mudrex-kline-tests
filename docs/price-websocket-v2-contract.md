# Price WebSocket API v2 — Contract Reference

**Source:** Engineering contract  
**Auth:** None — standard WebSocket upgrade  
**Keepalive:** Server closes after **40s inactivity**; any client message resets timer. Recommended **PING every 20s**.

Subscriptions are per-connection and **not persisted** — re-subscribe after reconnect.

---

## Endpoints

| Market | WebSocket URL |
|---|---|
| Spot | `wss://price.mudrex.com/api/v2/spot` |
| Linear (futures/perps) | `wss://price.mudrex.com/api/v2/linear` |

Staging (if available): replace host with `price.staging.mudrex.com`.

---

## Request envelope

All client messages use the same shape:

```json
{
  "id": 1,
  "method": "SUBSCRIBE",
  "params": ["kline@1m@btcusdt"],
  "assets": ["btcusdt"]
}
```

| Field | Type | Description |
|---|---|---|
| `id` | int | Correlation ID; echoed in responses |
| `method` | string | `SUBSCRIBE`, `UNSUBSCRIBE`, or `LIST_SUBSCRIPTIONS` |
| `params` | string[] | Stream names to act on |
| `assets` | string[] | Asset symbols — **only used when `ticker@5s` is in params**; ignored otherwise |

**Mixing stream types in one request is valid:**

```json
{
  "id": 1,
  "method": "SUBSCRIBE",
  "params": ["kline@1s@btcusdt", "ticker@5s"],
  "assets": ["btcusdt"]
}
```

**All-or-nothing:** if any stream in `params` is invalid, the entire request is rejected.

---

## Response envelope

Every request gets a response **before** stream data is pushed.

**Success:**

```json
{ "method": "SUBSCRIBE", "id": 1, "result": "success" }
```

**Error (application-level codes, not HTTP):**

```json
{ "method": "SUBSCRIBE", "id": 1, "error": { "code": 400, "msg": "invalid stream name: kline@5m@btcusdt" } }
```

---

## Available streams

| Stream | Name format | Endpoints | Notes |
|---|---|---|---|
| Kline 1-second | `kline@1s@<symbol>` | spot, linear | OHLCV candle |
| Kline 1-minute | `kline@1m@<symbol>` | spot, linear | OHLCV candle |
| Mark Kline 1-second | `markKline@1s@<symbol>` | **linear only** | OHLC, no volume |
| Mark Kline 1-minute | `markKline@1m@<symbol>` | **linear only** | OHLC, no volume |
| Ticker 5-second | `ticker@5s` | spot, linear | Changed prices every 5s |

**Symbol format:** lowercase, no slash — e.g. `btcusdt`, `ethusdt`, `solusdt`, `xrpusdt`.

---

## Subscribe examples

### Klines

```json
{
  "id": 1,
  "method": "SUBSCRIBE",
  "params": ["kline@1m@btcusdt", "kline@1s@ethusdt"]
}
```

### Mark klines (linear only)

```json
{
  "id": 2,
  "method": "SUBSCRIBE",
  "params": ["markKline@1m@btcusdt"]
}
```

### Ticker

Stream in `params`, symbols in `assets`:

```json
{
  "id": 3,
  "method": "SUBSCRIBE",
  "params": ["ticker@5s"],
  "assets": ["btcusdt", "ethusdt"]
}
```

On successful ticker subscribe, server sends an **immediate snapshot** of last known tickers for newly-added assets.

---

## Unsubscribe examples

### Klines

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

## List subscriptions

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
    "ticker_assets": ["btcusdt", "ethusdt"]
  }
}
```

---

## Push data format

All server pushes:

```json
{ "stream": "<stream-name>", "data": <payload> }
```

### Kline push

Stream: `kline@1m@btcusdt`

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
|---|---|
| `s` | Symbol |
| `t` | Candle open time (Unix seconds) |
| `o` | Open |
| `h` | High |
| `l` | Low |
| `c` | Close |
| `v` | Volume |

### Mark kline push (linear only)

Stream: `markKline@1m@btcusdt` — same envelope, **no `v` field**:

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

### Ticker push

Stream: `ticker@5s`

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
|---|---|
| `s` | Symbol |
| `p` | Last price (LTP) |
| `mp` | Mark price — **linear endpoint only**; omitted when unavailable |

Only assets whose price changed in the 5s window are included. No message if nothing changed.

---

## Limits and errors

| Limit | Value |
|---|---|
| Max active subscriptions per connection | **15** |
| `ticker@5s` | Counts as **1** subscription regardless of asset count |
| Ticker asset count | Unlimited; does not count toward cap |

| Code | Message | Cause |
|---|---|---|
| 400 | `invalid JSON` | Malformed request body |
| 400 | `unknown method` | Invalid `method` value |
| 400 | `invalid stream name: <x>` | Unrecognised stream or unsupported interval |
| 400 | `not subscribed: <x>` | Unsubscribing from inactive stream |
| 429 | `subscription limit reached` | Would exceed 15 subscriptions |

---

## REST vs WebSocket v1 vs WebSocket v2

| API | Base | Protocol |
|---|---|---|
| Data Read Client REST | `https://price.mudrex.com/api/v1` | HTTP |
| Raw klines WS (legacy) | `wss://price.mudrex.com/api/v1/klines` | Query-param subscribe |
| **Price WS v2** | `wss://price.mudrex.com/api/v2/spot` or `/linear` | JSON `SUBSCRIBE` envelope |

For futures testing, use **`/api/v2/linear`** for LTP klines, mark klines, and ticker with mark price.
