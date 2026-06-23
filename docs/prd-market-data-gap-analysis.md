# PRD Market Data — Gap Analysis

**PRD:** Decision layer / Mudrex-native market data  
**Tested:** 2026-06-20 against production  
**API reference:** [`futures-klines-and-price-websocket.md`](futures-klines-and-price-websocket.md)

---

## Product decisions (confirmed)

| Topic | Decision |
|---|---|
| **Host** | Market data stays on **`price.mudrex.com`** (not proxied through `trade.mudrex.com/fapi`) |
| **Field names** | Use **live API names** (`p`, `mp`, `1d_high`, array candles, etc.) — not PRD snake_case (`mark_price`, `high_24h`, …) |
| **Pagination** | **`start_time` / `end_time` windowing** with **1440-candle cap** per request — no `limit` param |
| **Intervals** | Use **native tokens** (`3t`, `5t`, `15t`, `30t`, `1mth`, …) — no `3m`/`5m` aliases |
| **Authentication** | **No auth** on Price REST or WebSocket — public market data |

---

## Executive summary

| PRD section | Status | Where it lives today |
|---|---|---|
| §6.1 Historical LTP kline (REST) | **Available** | `price.mudrex.com/api/v1` |
| §6.2 Mark-price kline (REST) | **Available** | Same Price API |
| §6.3 Market ticker snapshot (REST) | **Partial** | Trade listing has some fields; dedicated ticker TBD |
| §6.4 WebSocket price stream | **Available** | `wss://price.mudrex.com/api/v2/linear` — public, kline + ticker |
| §6.5 Rate limits | **Undocumented** | No rate-limit headers on Price API yet |
| §7 WS lifecycle | **Partial** | Idle timeout / heartbeat need doc alignment |

**Bottom line:** Klines (LTP + mark) and WebSocket kline/ticker **ship on `price.mudrex.com`** with no auth. Remaining work is mainly **§6.3 REST ticker fields** and doc polish — not host, pagination, interval, or auth changes.

---

## §6.1 Historical kline (REST)

| Requirement | Available? | Test result |
|---|---|---|
| No authentication | **Yes** | `GET /assets/price` → 200 without `X-Authentication` |
| LTP OHLCV for futures symbol | **Partial** | Full OHLCV via single-asset `/klines?ohlcv=true&type=linear`. Bulk 4-param returns close-only (o,h,l,v=0) |
| Symbol + interval + start/end | **Yes** | `btc/usdt`, `aggregation`, `start_time`, `end_time` |
| Optional `limit` + pagination | **Yes (by design)** | Paginate with `start_time`/`end_time`; max **1440 candles** per call — no `limit` param |
| Intervals (`3t`, `5t`, …) | **Yes (by design)** | Native tokens — `3m`/`5m` not aliased; use `3t`/`5t`/`15t`/`30t`/`1mth` |
| Response as numeric arrays | **Yes (by design)** | 6-field LTP / 5-field mark arrays — not snake_case objects |
| Numeric values as strings | **N/A** | JSON floats (Trade API uses strings; Price API does not) |
| Historical depth | **Yes** | Walk arbitrary history by shifting time windows (1440 candles per request) |
| Empty future range → 200 [] | **Yes** | Tested |
| Error contract (`/docs/error-handling`) | **Partial** | Price API uses `{success, errors:[{code,text}]}` — different host/shape from Trade API |

### Supported intervals (official)

| Token | Description |
|---|---|
| `1m` | 1 minute |
| `3t` | 3 minutes |
| `5t` | 5 minutes |
| `10t` | 10 minutes |
| `15t` | 15 minutes |
| `30t` | 30 minutes |
| `1h` | 1 hour |
| `4h` | 4 hours |
| `6h` | 6 hours |
| `12h` | 12 hours |
| `1d` | 1 day |
| `1w` | 1 week |
| `1mth` | 1 month |

No aliases — `3m`, `5m`, `15m`, `30m`, `1M` return `400`.

---

## §6.2 Mark-price kline (REST)

| Requirement | Available? | Test result |
|---|---|---|
| Mark OHLC candles | **Yes** | Single: `GET /asset/btc/usdt/mark-price`. Bulk: `GET /assets/mark-price` |
| Same contract as §6.1 | **Partial** | 5 fields (no volume); same interval/pagination gaps |
| Aligns to Mudrex liquidation mark | **Assumed** | Mark ≠ LTP in live samples (expected) |

---

## §6.3 Market ticker (REST)

Uses **live field names** (not PRD snake_case). Dedicated ticker endpoint not built yet.

| Field (docs) | Available? | Live source |
|---|---|---|
| `mp` / mark (WS) | **WS only** | `ticker@5s` → `mp` |
| `funding_fee_perc` | **Partial** | Trade listing — settlement rate |
| `funding_interval` | **Partial** | Trade listing — next funding epoch |
| `1d_high` | **Partial** | Single asset detail |
| `1d_low` | **Partial** | Single asset detail |
| `last_day_price` | **Partial** | Trade listing |
| `1d_volume` / `volume` | **Partial** | Single asset / listing |
| `index_price` | **No** | `/index-price` → 404 |
| Single-symbol snapshot endpoint | **No** | Use `GET /fapi/v1/futures/BTCUSDT?is_symbol` (partial fields) |
| All-symbols snapshot | **No** | Listing exists but lacks PRD fields |
| `/market/stats` | **Empty** | `GET /api/v1/market/stats?symbols=btc/usdt&type=linear` → `data: []` |

### Trade API fields available today (`GET /fapi/v1/futures/BTCUSDT?is_symbol`)

```
price, last_day_price, change_perc, volume, funding_fee_perc, funding_interval,
1d_high, 1d_low, 1d_volume, min_contract, max_leverage, …
```

Auth required (`X-Authentication`).

---

## §6.4 WebSocket price stream

| Requirement | Available? | Test result |
|---|---|---|
| No auth at handshake | **Yes** | Connected and subscribed without API key |
| Kline by symbol + interval | **Yes** | `kline@1m@btcusdt`, `kline@1s@btcusdt` — push on minute/second boundary |
| Snapshot of open candle on subscribe | **Not verified** | Subscribe ack only; first kline at boundary |
| Closed-candle flag | **No** | Push has `o,h,l,c,v,t,s` — no `confirm` / `closed` field |
| Push ≥1/sec while candle updating | **Partial** | 1s stream yes; 1m stream updates at minute close |
| Ticker by symbol | **Partial** | `ticker@5s` with `p` (LTP) + `mp` (mark) only |
| Full §6.3 fields on ticker WS | **No** | No funding, 24h stats, index, OI |
| Multi-symbol / multi-topic | **Yes** | Multiple streams + `assets` array for ticker |
| Max subscriptions per connection | **Yes** | 15 — 16th returns 429 |
| Authenticated connection per API key | **No** | Public WS; PRD expects auth |
| Account streams | **Out of scope** | Not available (expected) |

### Live WS ticker fields

```json
{ "s": "btcusdt", "p": 63697.9, "mp": 63698 }
```

---

## §6.5 Rate limits

| Requirement | Available? | Test result |
|---|---|---|
| Enhanced REST tier (e.g. 30/s) | **Unknown** | No `X-RateLimit-*` headers on Price API responses |
| 429 `RATE_LIMIT_EXCEEDED` | **Not tested** | Trade API pattern documented; Price API untested |
| WS connection limits documented | **Partial** | 15 subs/connection confirmed; per-key connection limit N/A (no auth) |

---

## §7 WebSocket connection lifecycle

| Requirement | Available? | Test result |
|---|---|---|
| Client PING → server PONG | **No** | Plain `"PING"` → `invalid JSON`. JSON envelope required |
| Server idle close (~40s) | **Partial** | Documented 40s; connection still open after 55s in test |
| Reconnect + resubscribe | **Yes** | Subscriptions not persisted (documented) |
| Snapshot on resubscribe (ticker) | **Yes** | Immediate ticker snapshot on subscribe |

---

## Additional PRD items not available

| Item | Status |
|---|---|
| Order book depth stream | Not available |
| Public trade prints | Not available |
| Liquidation feed | Not available |
| Index-price kline | Not available |
| Open interest | `/open-interest` → 404 |
| Spot market data | Separate host/path (out of PRD futures scope) |
| WS account streams | Not available |
| Authentication | **Public (by design)** | No API key on Price REST or WS |

---

## Remaining gaps (engineering / future)

| Item | Status |
|---|---|
| §6.3 dedicated REST ticker endpoint | Not built — use Trade listing + WS `ticker@5s` today |
| Bulk 4-param close-only candles (F1) | Open — PM to confirm external contract |
| WS closed-candle flag | Not in push payload |
| WS idle timeout enforcement | Doc says 40s; may not close within 55s |
| Rate-limit headers on Price API | Undocumented |
| Index price / open interest REST | 404 |

---

## Test artifacts

| File | Contents |
|---|---|
| `testing/prd-market-data-detail.json` | Intervals, trade listing, WS samples |
| `testing/prd-market-data-compliance.json` | Partial compliance run |
| `testing/futures-price-user-test.json` | REST user samples |
| `testing/futures-price-ws-user-test.json` | WS samples |
| `testing/price-rest-360-results.json` | Full REST 360° |
| `testing/price-ws-360-results.json` | Full WS 360° |
