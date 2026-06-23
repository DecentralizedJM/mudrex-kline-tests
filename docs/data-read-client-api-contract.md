# Data Read Client — API Contract Reference

**Source:** Engineering contract (Data Read Client)  
**Base path:** `/api/v1`  
**External domains:** `price.mudrex.com`, `price.staging.mudrex.com`  
**Internal domains:** `eu-west-1.dstaging.mudrex.intranet`, `eu-west-1.dproduction.mudrex.intranet`

**Related artifacts:** REST Postman Collection, gRPC Postman Collection, Protobuf Contracts

---

## Common query parameters

| Param | Description |
|---|---|
| `latest` | If set, return only this minute's price; reject older price |
| `reverse` | Enforce reverse asset pair price check. True if `derive` is passed |
| `derive` | Fetch asset price using all possible ways |
| `ohlcv` | Fetch kline data; if not passed, return close price in `price` key |
| `partial` | Bulk fetch: best-effort vs strict |
| `exchange` | Exchange name; falls back to any available if not found |
| `aggregation` | Timesteps to aggregate data for (klines / WS interval) |
| `assets` | List of assets for bulk price fetch |
| `type` | Asset type: `SPOT`, `LINEAR` (default `SPOT`; requires baseplate.go >= v2.12.6) |
| `cutoff` | Seconds to honor when computing latest price (baseplate.go >= v2.12.13) |
| `from` | Pagination offset (useless without `size`) |
| `size` | Page size |
| `base_currency` | Filter by base currency |
| `quote` | Filter by quote currency |
| `start_time` | Filter from start time (inclusive) |
| `end_time` | Filter till end time (inclusive) |
| `duration` | Klines for duration from current time |
| `config` | WS format: `<interval>:assets` — interval between klines, assets = base_currency list |
| `func` | Aggregation function for aggregated WS (default: `minmax`) |

---

## Metadata endpoints

| API | gRPC | Path | Query params |
|---|---|---|---|
| Asset Info | GetAsset | `/api/v1/asset/:base_currency/:quote_currency` | `type` optional |
| List assets | GetAssets | `/api/v1/assets` | — |
| List exchanges | GetExchanges | `/api/v1/exchanges` | — |
| Exchange assets | GetExchangeAssets | `/api/v1/exchange/:exchange/assets` | `from`, `size`, `base_currency` optional |
| Exchange info | GetExchange | `/api/v1/exchange/:exchange` | — |
| Currencies | — | `/api/v1/currencies` | — |

---

## Market data endpoints

| Use case | Path | Notes |
|---|---|---|
| Currency market stats | `/api/v1/market/stats` | `symbols` required; `quote` optional (default `usdt`, allowed: `usdt`, `inr`) |
| Market cap | `/api/v1/marketcap` | `size`, `from`, `quote` optional |
| Market aggregate | `/v1/market/aggregate` | `time_step`, `start_time`, `end_time` required; `quote` optional |
| Market cap categories | `/api/v1/market/categories` | `size`, `from`, `quote` optional |
| Category details | `/api/v1/market/category/{id}` | `id` required; `quote` optional |

---

## Price endpoints (LTP / spot price)

| Use case | gRPC | Path | Key params |
|---|---|---|---|
| Asset price | GetAssetPrice | `/api/v1/asset/:base_currency/:quote_currency/price` | `exchange`, `latest`, `reverse`, `derive`, `ohlcv`, `type`, `cutoff` |
| Bulk prices | GetBulkAssetsPrices | `/api/v1/assets/price` | `assets` required; same optional as single |
| **Last price (LTP)** | GetAssetLastPrice | `/api/v1/asset/:base_currency/:quote_currency/last-price` | `exchange`, `ohlcv`, `type` |
| Klines (time range) | GetAssetKlines | `/api/v1/asset/:base_currency/:quote_currency/klines` | `start_time`, `end_time`, `aggregation` required; `ohlcv`, `exchange`, `type` |
| Bulk klines (time range) | GetBulkAssetsPrices | `/api/v1/assets/price` | External: `assets`, `aggregation`, `start_time`, `end_time`. Internal testing: `ohlcv`, `partial`, `type` |

**External params (PM):** `assets`, `aggregation`, `start_time`, `end_time` only.

**Asset format:** `btc/usdt` (lowercase slash).

**LTP bulk klines response** — `data.asset_ticks["btc/usdt"]` arrays of **6** values: `[open_time, open, high, low, close, volume]`

**Verified live on prod:** 2026-06-17 — matches dev sample exactly.
| Klines (duration) | GetAssetKlines | `/api/v1/asset/:base_currency/:quote_currency/klines` | `duration` required (`1d`, `1w`, `1y`, `3y`); `aggregation` (`30t`, `1d`) |
| 1s klines | GetAssetKlines | same klines path | `duration` [0–129600]; `aggregation=1s` |

### Kline aggregation values

**SPOT:** `1m`, `15t`, `30t`, `1h`, `6h`, `1d`, `1w`, `1mth`  
**LINEAR:** `1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth`

---

## Mark price endpoints

| Use case | Path | Key params |
|---|---|---|
| Mark price (single/bulk) | `/api/v1/assets/mark-price` | `assets` required; `exchange`, `partial`, `ohlcv`, `latest`, `cutoff` optional |
| Mark klines (time range) | `/api/v1/asset/:base_currency/:quote_currency/mark-price` | `start_time`, `end_time`, `aggregation` required; `exchange`, `ohlcv` (default false) |
| Mark klines (bulk) | `/api/v1/assets/mark-price` | Same params/response shape as bulk LTP; candles have **5** fields (no volume) |

**Mark bulk klines response** — arrays of **5** values: `[open_time, open, high, low, close]`

**Verified live on prod:** 2026-06-17 — matches sandbox sample from dev.

**Mark kline aggregation:** `1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth`

---

## WebSocket endpoints

**Base path:** `/api/v1/klines` (upgrade to WebSocket)

### Realtime klines

| Param | Required | Values |
|---|---|---|
| `type` | Optional | `SPOT`, `LINEAR` |
| `quote` | Optional | e.g. `usdt` |
| `aggregation` | Optional | `1s`, `1m` |
| `exchange` | Optional | — |
| `config` | Optional | `<interval>:assets` |

### Aggregated realtime klines

| Param | Required | Values |
|---|---|---|
| `aggregation` | Required | `2s`–`59s` |
| `quote` | Optional | — |
| `func` | Optional | default `minmax` |

---

## Mudrex Futures testing notes

- Futures/perps: use `type=LINEAR`, quote typically `usdt` (e.g. BTC + USDT → `BTC` / `USDT`).
- **LTP klines:** `/api/v1/asset/{base}/{quote}/klines?ohlcv=true&type=LINEAR&...`
- **Mark price klines:** `/api/v1/asset/{base}/{quote}/mark-price?ohlcv=true&...`
- **LTP spot price:** `/api/v1/asset/{base}/{quote}/last-price?type=LINEAR`
- **Mark price bulk:** `/api/v1/assets/mark-price?assets=...&ohlcv=true`
- External base: `https://price.mudrex.com/api/v1/...`
- Staging: `https://price.staging.mudrex.com/api/v1/...`

This service is separate from the trading API (`trade.mudrex.com/fapi/v1`).

**WebSocket v2 (recommended for real-time):** see [`price-websocket-v2-contract.md`](price-websocket-v2-contract.md) — `wss://price.mudrex.com/api/v2/linear` with JSON `SUBSCRIBE` envelope.
