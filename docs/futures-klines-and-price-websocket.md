# Futures Market Data — Klines, Ticker & WebSocket

Market data for Mudrex **USDT-margined linear perpetual futures**. Covers PRD §6 (historical klines, mark klines, ticker snapshot, WebSocket stream) mapped to **what is live today** on production.

**Tested:** 2026-06-20  
**Gap analysis:** [`prd-market-data-gap-analysis.md`](prd-market-data-gap-analysis.md)

---

## Product decisions

| Topic | Decision |
|---|---|
| Host | **`price.mudrex.com`** for all market data (REST + WS) |
| Field names | **Live API names** — array candles, `p`/`mp`, `1d_high`, etc. |
| Pagination | **`start_time` + `end_time`** windows; max **1440 candles** per request |
| Intervals | **`3t`, `5t`, `15t`, `30t`, `1mth`** — no `3m`/`5m` aliases |
| Authentication | **None** — public access |

---

## Capability summary

| Capability | Status | Section |
|---|---|---|
| Historical LTP kline (REST) | **Available** | §1 |
| Mark-price kline (REST) | **Available** | §2 |
| Market ticker snapshot (REST) | **Partial** | §3 |
| WebSocket price stream | **Available** | §4 |
| Rate limits | Undocumented | §5 |
| WS lifecycle | Partial | §6 |

> Trade API asset listing (§3) still requires `X-Authentication`. Price API klines and WS do not.

---

## Specifications

| | |
|---|---|
| Price REST | `https://price.mudrex.com/api/v1` |
| Price WebSocket (futures) | `wss://price.mudrex.com/api/v2/linear` |
| Trade REST (asset listing) | `https://trade.mudrex.com/fapi/v1` |
| Price API auth | **None** |
| Trade API auth | `X-Authentication: your-secret-key` |
| Price format | USDT (matches `BTCUSDT` contracts) |

### Symbol mapping

| Surface | Format | Example |
|---|---|---|
| Trade API | Uppercase | `BTCUSDT` |
| Price REST | Lowercase + slash | `btc/usdt` |
| Price WebSocket | Lowercase, no slash | `btcusdt` |

### Supported intervals

| Token | Minutes |
|---|---|
| `1m` | 1 |
| `3t` | 3 |
| `5t` | 5 |
| `10t` | 10 |
| `15t` | 15 |
| `30t` | 30 |
| `1h` | 60 |
| `4h` | 240 |
| `6h` | 360 |
| `12h` | 720 |
| `1d` | 1440 |
| `1w` | 10080 |
| `1mth` | ~30 days |

Use these tokens exactly. `3m`, `5m`, `15m`, `30m`, `1M` are **not** accepted.

### Response shape

Candles are **numeric arrays** (not snake_case objects):

**LTP (6 fields):** `[open_time, open, high, low, close, volume]`  
**Mark (5 fields):** `[open_time, open, high, low, close]`

### Pagination

Paginate by shifting `start_time` and `end_time`. Each request returns at most **1440 candles**. Example: for 1m data, one call covers up to 24 hours; chain windows to walk further back.

```bash
# Window 1: hours 0–24
curl "...&start_time=T0&end_time=T0+86400"
# Window 2: hours 24–48
curl "...&start_time=T0+86400&end_time=T0+172800"
```

---

## §1 — Historical LTP kline (REST) · PRD §6.1

Last-trade-price OHLCV candles for futures.

### 1.1 Bulk klines — `GET /assets/price`

Best for multi-symbol pulls. Standard user parameters (four query params).

#### Request

```bash
curl -X GET "https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&aggregation=1m&start_time=1781926400&end_time=1781930000"
```

#### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `assets` | query | string | Yes | `btc/usdt` or comma-separated list |
| `aggregation` | query | string | Yes | Interval — see mapping table |
| `start_time` | query | integer | Yes | Unix seconds, inclusive |
| `end_time` | query | integer | Yes | Unix seconds, inclusive |

#### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781929680, 0, 0, 0, 63564.8, 0],
                [1781929740, 0, 0, 0, 63566.1, 0]
            ]
        }
    }
}
```

> With these four parameters, `open`/`high`/`low`/`volume` are `0`; **close is at index 4**. For full OHLCV use §1.2.

#### Multi-asset

```bash
curl -X GET "https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt,eth/usdt&aggregation=1m&start_time=1781926400&end_time=1781930000"
```

---

### 1.2 Single-asset klines (full OHLCV) — `GET /asset/:base/:quote/klines`

Recommended for backtesting and charting with complete candles.

#### Request

```bash
curl -X GET "https://price.mudrex.com/api/v1/asset/btc/usdt/klines?start_time=1781926400&end_time=1781930000&aggregation=1m&ohlcv=true&type=linear"
```

#### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `base` | path | string | Yes | e.g. `btc` |
| `quote` | path | string | Yes | e.g. `usdt` |
| `start_time` | query | integer | Yes | Unix seconds |
| `end_time` | query | integer | Yes | Unix seconds |
| `aggregation` | query | string | Yes | Interval |
| `ohlcv` | query | boolean | Yes | `true` |
| `type` | query | string | Yes | `linear` for futures |

#### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "ticks": [
            [1781929620, 63495.5, 63512, 63495.4, 63506.1, 25.008],
            [1781929680, 63506.1, 63532, 63506.1, 63532, 31.489],
            [1781929740, 63532, 63536, 63529.2, 63531, 11.873]
        ]
    }
}
```

| Index | Field |
|---|---|
| 0 | `open_time` |
| 1 | `open` |
| 2 | `high` |
| 3 | `low` |
| 4 | `close` |
| 5 | `volume` |

#### History depth & pagination

| Range (1m) | Candles returned |
|---|---|
| 2 hours | ~120 |
| 24 hours | ~1440 |
| 25+ hours | **1440 (cap)** |

Walk history by chaining `start_time`/`end_time` windows. No `limit` query parameter.

#### Response — future range (empty)

```json
{
    "success": true,
    "data": {
        "ticks": []
    }
}
```

#### Response — 400 invalid interval

```json
{
    "success": false,
    "errors": [
        { "code": 400, "text": "3m aggregation not supported" }
    ]
}
```

#### Response — 400 invalid time range

```json
{
    "success": false,
    "errors": [
        { "code": 400, "text": "end time should be greater than start time" }
    ]
}
```

---

### 1.3 Last price — `GET /asset/:base/:quote/last-price`

Point-in-time LTP (not a kline series).

#### Request

```bash
curl -X GET "https://price.mudrex.com/api/v1/asset/btc/usdt/last-price?type=linear"
```

#### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "price": 63485.6,
        "time": 1781929920,
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

## §2 — Mark-price kline (REST) · PRD §6.2

Fair-value candles used for PnL and liquidation. Same intervals and caps as §1.

### 2.1 Bulk mark klines — `GET /assets/mark-price`

#### Request

```bash
curl -X GET "https://price.mudrex.com/api/v1/assets/mark-price?assets=btc/usdt&aggregation=1m&start_time=1781926400&end_time=1781930000"
```

#### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "asset_ticks": {
            "btc/usdt": [
                [1781929680, 0, 0, 0, 63500.1],
                [1781929740, 0, 0, 0, 63501.2]
            ]
        }
    }
}
```

5 fields per candle; close-only with four standard params (same as §1.1).

---

### 2.2 Single-asset mark klines — `GET /asset/:base/:quote/mark-price`

#### Request

```bash
curl -X GET "https://price.mudrex.com/api/v1/asset/btc/usdt/mark-price?start_time=1781926400&end_time=1781930000&aggregation=1m&ohlcv=true"
```

#### Response — 200 OK

```json
{
    "success": true,
    "data": {
        "ticks": [
            [1781929620, 63500.1, 63512, 63499.94, 63506.1],
            [1781929680, 63506.1, 63512, 63506.1, 63532],
            [1781929740, 63532, 63536, 63529.2, 63531]
        ]
    }
}
```

| Index | Field |
|---|---|
| 0 | `open_time` |
| 1 | `open` (mark) |
| 2 | `high` (mark) |
| 3 | `low` (mark) |
| 4 | `close` (mark) |

Mark close differs from LTP close for the same minute (expected).

---

## §3 — Market ticker (REST)

**Status: Partial** — see [Why Partial](#why-partial) below.

A dedicated ticker endpoint is **not built yet**. Use Trade API asset data (auth required) for snapshot fields, and WebSocket `ticker@5s` for live `p` + `mp`.

Field names below are **live API names** (not PRD snake_case).

### Why Partial

PRD §6.3 asks for a **single REST snapshot** per symbol (and all symbols) with live market state: last price, **mark price**, dynamic funding rate, next funding time, and 24h stats — usable for signal triggers and risk checks in **one call**.

That endpoint does not exist today. What you have instead is a **patchwork of three surfaces**:

| Need | Where today | Gap |
|---|---|---|
| Last price + 24h change/volume | Trade API `GET /futures/BTCUSDT?is_symbol` | Requires **auth**; different host (`trade.mudrex.com`) |
| Mark price | WS `ticker@5s` → `mp`, or §2 mark klines | **Not on REST ticker** — must subscribe or pull klines |
| 24h high/low | Trade single-asset only (`1d_high`, `1d_low`) | **Not on list endpoint**; not on Price API |
| Funding | `funding_fee_perc` + `funding_interval` on Trade listing | Settlement rate + epoch — not a unified ticker field |
| All symbols, one call | `GET /futures?limit=N` (paginated) | Partial fields; no mark, no `1d_high`/`1d_low` per row |
| Price API ticker | `GET /market/stats`, `/ticker` probes | **`data: []` or 404** — not implemented |

**PRD user story today:**  
*“Pull one ticker snapshot with mark price and funding for risk checks.”*

You must combine:

1. `GET trade.mudrex.com/fapi/v1/futures/BTCUSDT?is_symbol` (auth) → `price`, `1d_high`, `funding_fee_perc`, …
2. `GET price.mudrex.com/.../last-price?type=linear` (no auth) → LTP only, no mark
3. Or `wss://price.mudrex.com/api/v2/linear` + `ticker@5s` → `p` + `mp` (live, not REST)

**What would make it “Available”:**  
A REST endpoint on `price.mudrex.com` returning per-symbol snapshot with `price`, `mp` (mark), funding fields, and 24h stats in **one unauthenticated response** — same host as klines.

§6.1, §6.2, and §6.4 are complete. §6.3 is the missing piece for “one REST call for full market state.”

### 3.1 What is available today — Trade API asset listing

Requires authentication. Closest partial match to PRD §6.3.

#### Single symbol — `GET /futures/:symbol`

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT?is_symbol" \
  -H "X-Authentication: your-secret-key"
```

#### Response — 200 OK (live sample)

```json
{
    "success": true,
    "data": {
        "id": "01903a7b-bf65-707d-a7dc-d7b84c3c756c",
        "name": "Bitcoin",
        "symbol": "BTCUSDT",
        "price": "63681.1",
        "last_day_price": "62581.5",
        "change_perc": "1.75706878230787",
        "volume": "48436.564",
        "funding_fee_perc": "-0.00000473",
        "funding_interval": 1781942400,
        "1d_high": 63945.7,
        "1d_low": 62271.6,
        "1d_volume": 48436.564000000035,
        "min_contract": "0.001",
        "max_leverage": "100"
    }
}
```

#### Field reference (live names)

| Field | Description |
|---|---|
| `price` | Last traded price (USDT string) |
| `last_day_price` | Previous day reference price |
| `change_perc` | 24h change % |
| `volume` | Volume |
| `funding_fee_perc` | Funding settlement rate |
| `funding_interval` | Next funding time (Unix epoch) |
| `1d_high` | 24h high (single-asset detail only) |
| `1d_low` | 24h low (single-asset detail only) |
| `1d_volume` | 24h volume (single-asset detail only) |

Mark price on REST: use §2 mark klines or WS `mp` field.

#### All symbols — `GET /futures`

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures?sort=price&order=desc&offset=0&limit=20" \
  -H "X-Authentication: your-secret-key"
```

Returns paginated array; same core fields as above (no `1d_high`/`1d_low` on list items — only on single-asset detail).

### 3.2 Not available

| Endpoint | Result |
|---|---|
| `GET /fapi/v1/futures/ticker` | 404 |
| `GET /fapi/v1/futures/BTCUSDT/ticker` | 404 |
| `GET /api/v1/market/stats?symbols=btc/usdt&type=linear` | 200, `data: []` |

---

## §4 — WebSocket price stream

Real-time klines and ticker for futures. **No authentication** required.

### Connection

```
wss://price.mudrex.com/api/v2/linear
```

| Limit | Value |
|---|---|
| Max subscriptions per connection | **15** (16th → 429) |
| `ticker@5s` | Counts as 1 subscription |

---

### 4.1 Request envelope

```json
{
    "id": 1,
    "method": "SUBSCRIBE",
    "params": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
    "assets": ["btcusdt"]
}
```

| Field | Description |
|---|---|
| `id` | Correlation ID |
| `method` | `SUBSCRIBE` · `UNSUBSCRIBE` · `LIST_SUBSCRIPTIONS` |
| `params` | Stream names |
| `assets` | Required when `ticker@5s` is in `params` |

#### Subscribe response — success

```json
{
    "method": "SUBSCRIBE",
    "id": 1,
    "result": "success"
}
```

---

### 4.2 Streams (futures)

| Stream | Example | Description |
|---|---|---|
| LTP kline 1s | `kline@1s@btcusdt` | Second candles |
| LTP kline 1m | `kline@1m@btcusdt` | Minute candles |
| Mark kline 1s | `markKline@1s@btcusdt` | Mark second candles |
| Mark kline 1m | `markKline@1m@btcusdt` | Mark minute candles |
| Ticker | `ticker@5s` | LTP + mark, 5s cadence |

---

### 4.3 Push — LTP kline

```json
{
    "stream": "kline@1m@btcusdt",
    "data": {
        "s": "btcusdt",
        "t": 1781933220,
        "o": 63681.1,
        "h": 63698,
        "l": 63668.9,
        "c": 63668.9,
        "v": 14.904
    }
}
```

1m klines push at minute boundaries. No separate closed-candle flag in the payload.

---

### 4.4 Push — mark kline

```json
{
    "stream": "markKline@1m@btcusdt",
    "data": {
        "s": "btcusdt",
        "t": 1781933220,
        "o": 63684.3,
        "h": 63698,
        "l": 63674.48,
        "c": 63674.49
    }
}
```

---

### 4.5 Push — ticker

```json
{
    "stream": "ticker@5s",
    "data": [
        { "s": "btcusdt", "p": 63697.9, "mp": 63698 }
    ]
}
```

| Field | Description |
|---|---|
| `p` | Last traded price (LTP) |
| `mp` | Mark price |

Funding and 24h stats are not on the WS ticker — use §3 Trade listing.

On subscribe, server sends an immediate ticker snapshot for new assets.

---

### 4.6 UNSUBSCRIBE

```json
{
    "id": 2,
    "method": "UNSUBSCRIBE",
    "params": ["kline@1m@btcusdt"]
}
```

```json
{
    "id": 3,
    "method": "UNSUBSCRIBE",
    "params": ["ticker@5s"],
    "assets": ["btcusdt"]
}
```

---

### 4.7 LIST_SUBSCRIPTIONS

**Request:**

```json
{ "id": 4, "method": "LIST_SUBSCRIPTIONS" }
```

**Response:**

```json
{
    "id": 4,
    "method": "LIST_SUBSCRIPTIONS",
    "result": {
        "subscriptions": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
        "ticker_5s_assets": ["btcusdt"],
        "ticker_1s_assets": []
    }
}
```

---

### 4.8 WebSocket errors

```json
{
    "method": "SUBSCRIBE",
    "id": 1,
    "error": { "code": 400, "msg": "invalid stream name: kline@5m@btcusdt" }
}
```

```json
{
    "method": "SUBSCRIBE",
    "id": 16,
    "error": { "code": 429, "msg": "subscription limit reached" }
}
```

| Code | Message |
|---|---|
| 400 | `invalid stream name` |
| 400 | `unknown method` |
| 400 | `invalid JSON` |
| 400 | `not subscribed` |
| 429 | `subscription limit reached` |

Invalid stream in a batch rejects the **entire** subscribe request.

---

## §5 — Rate limits · PRD §6.5

| Surface | Status |
|---|---|
| Price REST enhanced tier (30/s) | **Not documented** — no rate-limit headers observed |
| Price WS connection limits | 15 subscriptions/connection confirmed |
| Trade API standard tier | 10/s per existing docs |

---

## §6 — WebSocket lifecycle · PRD §7

| PRD requirement | Behavior |
|---|---|
| Authentication | **None** — public connect |
| Idle timeout ~40s | Send periodic JSON messages to stay alive |
| Reconnect | Subscriptions not persisted — resubscribe |
| Snapshot on resubscribe | Ticker: yes. Kline: at next candle boundary |

---

## §7 — Not in PRD scope / not available

| Item | Status |
|---|---|
| Order book depth | Not available |
| Trade prints | Not available |
| Liquidation feed | Not available |
| Index-price kline | Not available |
| Open interest REST | 404 |
| Spot market data | Out of scope (separate `api/v2/spot`) |
| WS account streams | Not available |
| Authenticated WS per API key | Not planned — public by design |

---

## Python example — pull 1m LTP + mark history

```python
import requests, time

BASE = "https://price.mudrex.com/api/v1"
end = int(time.time())
start = end - 3600  # 1 hour

ltp = requests.get(f"{BASE}/asset/btc/usdt/klines", params={
    "start_time": start, "end_time": end,
    "aggregation": "1m", "ohlcv": "true", "type": "linear",
}).json()

mark = requests.get(f"{BASE}/asset/btc/usdt/mark-price", params={
    "start_time": start, "end_time": end,
    "aggregation": "1m", "ohlcv": "true",
}).json()

print("LTP candles:", len(ltp["data"]["ticks"]))
print("Mark candles:", len(mark["data"]["ticks"]))
```

---

## JavaScript example — WebSocket subscribe

```javascript
const ws = new WebSocket("wss://price.mudrex.com/api/v2/linear");

ws.onopen = () => {
  ws.send(JSON.stringify({
    id: 1,
    method: "SUBSCRIBE",
    params: ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"],
    assets: ["btcusdt"],
  }));
};

ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.stream) console.log(msg.stream, msg.data);
};
```

---

## Related documents

| Doc | Purpose |
|---|---|
| [`prd-market-data-gap-analysis.md`](prd-market-data-gap-analysis.md) | Full PRD vs live gap matrix |
| [`mark-price-ltp-failures.md`](mark-price-ltp-failures.md) | Known bugs and flakes |
| [Mudrex Trade API overview](https://docs.trade.mudrex.com/docs/overview) | Orders, positions, wallet |

**Test artifacts:** `testing/prd-market-data-detail.json` · `testing/futures-price-user-test.json` · `testing/futures-price-ws-user-test.json`
