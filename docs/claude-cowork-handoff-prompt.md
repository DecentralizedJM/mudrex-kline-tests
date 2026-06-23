# Claude Cowork Handoff — Mudrex API / RexAlgo uPnL

Copy everything below the line into Claude Cowork to continue this work.

---

## PROMPT START

You are continuing work on **Mudrex Futures API testing and RexAlgo integration**. The workspace is `/Users/jm/Mudrex API Testing` (or a clone of it). Read the referenced docs and test artifacts before making changes.

---

### Project purpose

This repo tests and documents Mudrex **market data** (Price API) and **Trade API** (futures execution), with a focus on:

1. Klines (LTP + mark price) — REST and WebSocket
2. PRD compliance for market data phase
3. **RexAlgo** — streaming unrealized PnL for open positions (blocked today)

RexAlgo is a platform where many users trade via Mudrex API keys. **Rex is the source of truth** for users — they must see open positions and **live uPnL matching Mudrex app exactly**.

---

### Confirmed product decisions (do not re-litigate)

| Topic | Decision |
|---|---|
| **Market data host** | `price.mudrex.com` (NOT proxied through `trade.mudrex.com/fapi`) |
| **Auth on Price API** | **No auth** — public REST + WS |
| **Field names** | **Live API names** (`p`, `mp`, `1d_high`, array candles) — NOT PRD snake_case (`mark_price`, `high_24h`) |
| **Pagination** | `start_time` / `end_time` windows; **1440 candle cap** per request — acceptable, no `limit` param |
| **Intervals** | Native tokens: `1m`, `3t`, `5t`, `10t`, `15t`, `30t`, `1h`, `4h`, `6h`, `12h`, `1d`, `1w`, `1mth` — NO aliases (`3m` → 400) |
| **Bulk klines for single asset** | **Yes** — bulk `/assets/price` identical to single `/klines` when `ohlcv=true&type=linear` |
| **Mark on REST** | Not required if WS has `mp` — but mark klines REST works |
| **Index price / OI** | Not needed |
| **§6.3 REST ticker** | Partial — no dedicated ticker endpoint; Trade listing + WS ticker is enough for now |

---

### API surfaces

#### Price REST — `https://price.mudrex.com/api/v1` (no auth)

| Endpoint | Purpose |
|---|---|
| `GET /assets/price?assets=btc/usdt&aggregation=1m&start_time=&end_time=&ohlcv=true&type=linear` | Bulk LTP klines (works for single asset) |
| `GET /assets/mark-price?...` | Bulk mark klines |
| `GET /asset/btc/usdt/klines?ohlcv=true&type=linear` | Single LTP klines → `data.ticks` |
| `GET /asset/btc/usdt/mark-price?ohlcv=true` | Single mark klines → `data.ticks` |
| `GET /asset/btc/usdt/last-price?type=linear` | Point LTP |

**Bulk 4-param only** (no `ohlcv`): close-only candles — `o,h,l,v=0`, price at index 4.

**Candle format:** LTP = 6 fields `[open_time, o, h, l, c, volume]`; Mark = 5 fields, no volume.

#### Price WebSocket — `wss://price.mudrex.com/api/v2/linear` (no auth, futures only)

```json
{ "id": 1, "method": "SUBSCRIBE", "params": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"], "assets": ["btcusdt"] }
```

| Stream | Data |
|---|---|
| `ticker@5s` | `p` = LTP, `mp` = mark (both live) |
| `kline@1m@btcusdt` | LTP OHLCV |
| `markKline@1m@btcusdt` | Mark OHLC |

Limits: 15 subscriptions/connection; idle ~40s (may not enforce in 55s test).

Symbol mapping: Trade `BTCUSDT` → REST `btc/usdt` → WS `btcusdt`.

#### Trade REST — `https://trade.mudrex.com/fapi/v1` (auth: `X-Authentication`)

| Endpoint | Purpose |
|---|---|
| `GET /futures/positions` | Open positions — **NO `unrealized_pnl` today** |
| `GET /futures/BTCUSDT?is_symbol` | Asset detail — `price`, `funding_fee_perc`, `1d_high`, `1d_low`, … |
| `GET /futures/fee/history` | `TRANSACTION` + `FUNDING` fees |

Set `MUDREX_API_SECRET` via env or `.env` (copy from `.env.example`) before running Trade API or full 360 tests.

---

### Test results summary (2026-06-20)

**360° suite:** 53 PASS / 6 FAIL (59 tests) — see `Mark_Price_LTP_360_Test_Report.md`

**Still failing / open:**
- R3/R4: Bulk 4-param close-only (F1 — PM decision)
- R17: Single-asset 1s klines 404
- R22: Missing `start_time` returns 200 wrong shape
- W10: WS idle timeout not enforced in 55s
- W1-W4: Timing flake (no 1m kline in window)

**Fixed since earlier run:** R9 single mark klines 404 → now PASS

**Re-run tests:**
```bash
cd "/Users/jm/Mudrex API Testing"
bash testing/run_price_360.sh
```

---

### Key documentation files (read these first)

| File | Contents |
|---|---|
| `docs/futures-klines-and-price-websocket.md` | **Main user-facing API doc** — klines, WS, intervals, PRD mapping |
| `docs/prd-market-data-gap-analysis.md` | PRD §6 compliance vs live |
| `docs/mark-price-ltp-failures.md` | Known failures register |
| `docs/mark-price-ltp-websocket-api.md` | Internal API reference |
| `docs/rexalgo-upnl-problem-and-solution.md` | **Rex uPnL problem statement + Mudrex/Rex split** |
| `docs/rexalgo-streaming-upnl-solution.md` | Technical architecture for Rex streaming uPnL |
| `docs/unrealized-pnl-price-websocket-strategy.md` | Why Price WS alone cannot provide official uPnL |

---

### RexAlgo uPnL — the main unresolved problem

**Problem:** Rex cannot show live unrealized PnL. Mudrex `GET /futures/positions` has no `unrealized_pnl`. Price WS has `mp` but no position context. Client-side uPnL from `mp` will **not match Mudrex app** — unacceptable for Rex as source of truth.

**Solution (both teams):**

**Mudrex P0:** Add to open positions REST:
- `unrealized_pnl` (string, in `trade_currency`)
- `mark_price` (string, USDT)
- `computed_at` (unix)

**Mudrex P1:** Authenticated account WebSocket on Trade API:
- `wss://trade.mudrex.com/fapi/v1/ws` (proposed)
- `SUBSCRIBE` → `position` topic
- Events: `SNAPSHOT`, `UPNL_UPDATE`, `POSITION_OPENED`, `POSITION_CHANGED`, `POSITION_CLOSED`

**Rex P0:** Poll `GET /positions` every 1–2s → fan-out to Rex users via Rex WebSocket. **Never compute uPnL client-side.**

**Rex P1:** Subscribe to Mudrex account WS → relay pushes to Rex UI.

**Do NOT:** Put uPnL on public `price.mudrex.com` WS; Rex calculating from Price WS `mp`.

**Open questions for Mudrex:**
1. Is uPnL price-only or includes funding?
2. INR: `entry_hedge_rate` or live FX for uPnL?
3. REST ship date? Account WS ETA?
4. Max WS connections per API key?

---

### PRD context (market data phase)

Original PRD asked for: historical klines, mark klines, REST ticker, WS price stream, rate limits.

**Available today on `price.mudrex.com`:**
- §6.1 LTP klines — Available (bulk + single)
- §6.2 Mark klines — Available
- §6.3 REST ticker — Partial (Trade listing fields, no dedicated endpoint)
- §6.4 WS — Available (`p` + `mp` on ticker, klines, markKline)
- Account WS / uPnL — **Out of scope in PRD phase 1; needed for Rex**

---

### Test artifacts

| File | Contents |
|---|---|
| `testing/price-rest-360-results.json` | Full REST 360 results |
| `testing/price-ws-360-results.json` | Full WS 360 results |
| `testing/bulk-vs-single-klines.json` | Bulk = single asset proof |
| `testing/btc-1h-ohlcv-now.json` | Latest BTC 1h sample |
| `testing/prd-market-data-detail.json` | PRD probe results |
| `testing/futures-price-user-test.json` | Futures user API samples |

---

### What was NOT done / optional next steps

- [ ] Publish docs to `docs.trade.mudrex.com`
- [ ] Mudrex engineering ticket for `unrealized_pnl` REST + account WS
- [ ] RexAlgo implementation of uPnL poller + fan-out
- [ ] Resolve F1 (bulk 4-param close-only) with PM
- [ ] Re-run 360 suite after harness fixes for W1-W4 timing

---

### Instructions for Claude Cowork

1. Read `docs/rexalgo-upnl-problem-and-solution.md` and `docs/futures-klines-and-price-websocket.md` before proposing changes.
2. Respect confirmed product decisions above — do not suggest moving market data to Trade API or adding auth to Price API.
3. For Rex uPnL work, always recommend **Mudrex-computed** uPnL, not client math from Price WS.
4. Run live tests against production when validating API behavior (`price.mudrex.com`, `trade.mudrex.com`).
5. Do not commit unless asked. Do not edit `.cursor/plans/` files.

**My next goal is:** [USER: fill in what you want to work on next — e.g. "draft Mudrex engineering ticket for unrealized_pnl REST fields", "implement Rex uPnL poller spec", "publish API docs to trade.mudrex.com", etc.]

## PROMPT END
