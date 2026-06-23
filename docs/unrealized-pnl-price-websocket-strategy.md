# Unrealized PnL, Price WebSocket & Fees — Architecture Guide

**Context:** Mudrex Trade API docs do not expose `unrealized_pnl` on open positions. REST position snapshots go stale quickly if mark price moves. A **public Price WebSocket** (`wss://price.mudrex.com/api/v2/linear`) now streams live `mp` (mark) and `p` (LTP).

**Related:** [`futures-klines-and-price-websocket.md`](futures-klines-and-price-websocket.md) · [Open positions](https://docs.trade.mudrex.com/docs/get-open-positions)

**Tested:** 2026-06-20

---

## Current state

### What Trade REST returns for open positions

`GET /fapi/v1/futures/positions` (auth required):

| Field | Use for uPnL |
|---|---|
| `entry_price` | Yes — USDT |
| `quantity` | Yes — base asset |
| `order_type` / side | Yes — `LONG` / `SHORT` |
| `trade_currency` | Yes — USDT or INR |
| `entry_hedge_rate` | Yes — INR positions only |
| `liquidation_price`, `initial_margin`, … | Risk — not uPnL |
| **`unrealized_pnl`** | **Not returned** |

Realized `pnl` exists only on **closed** positions (`GET /futures/positions/history`).

### What Price WebSocket returns

`ticker@5s` on `wss://price.mudrex.com/api/v2/linear`:

```json
{ "s": "btcusdt", "p": 63697.9, "mp": 63698 }
```

| Field | Meaning |
|---|---|
| `p` | Last traded price (LTP) |
| `mp` | **Mark price** — used for liquidation & unrealized PnL on most exchanges |

`markKline@1m@btcusdt` also streams mark OHLC if you prefer kline cadence over ticker.

### What is NOT on Price WebSocket

- Position size, entry price, side
- Unrealized or realized PnL
- Funding rate accrual
- Trading / platform fees
- Wallet balance

---

## Why REST-only uPnL is stale

If you poll positions and mark price separately over REST:

```
T+0s   GET /positions        → entry_price, qty (snapshot A)
T+0s   GET mark via klines   → mark at T+0
T+5s   mark moves 0.3%       → position REST unchanged, uPnL wrong
```

Even a single “positions” response has **no mark price embedded**, so any uPnL you attach is already a client-side calculation using data from another call at another time.

**Conclusion:** Documenting a REST `unrealized_pnl` field that is only refreshed on poll would mislead API users — it would lag the app/UI unless mark and position are from the same instant (they are not today).

---

## Question 1 — Do we need a separate WebSocket for unrealized PnL?

### Short answer: **Not for mark-based uPnL.** Optional later for server-authoritative totals.

| Approach | Separate uPnL WS? | When to use |
|---|---|---|
| **A. Client-computed (recommended now)** | **No** | Cache position from Trade REST; recompute on each WS `mp` tick |
| **B. Account / position WS (PRD phase 2)** | **No** — one private WS with position topics | Server pushes position + uPnL when state changes |
| **C. Dedicated uPnL-only WS** | **No** — redundant | Only if uPnL logic is secret/complex and cannot be replicated |

### Recommendation

**Do not build a separate public uPnL WebSocket.**

1. **Now:** Document the **client-compute pattern** — Price WS for mark + Trade REST for position state.
2. **Next phase (per PRD):** Add **authenticated account WebSocket** topics (`position`, `wallet`) that include server-computed uPnL — same connection as order/execution streams, not a second public socket.

A standalone uPnL stream duplicates what a position topic would already push, and still would not replace fee history for funding already paid.

### When a server-pushed uPnL *is* needed

Publish WS/REST uPnL from Mudrex (not client math) if:

- UI uses internal rounding / hedge logic clients cannot reproduce
- Funding **accrued since open** is folded into displayed uPnL
- Algo partners must match Mudrex app **to the cent** without reverse-engineering

Until then, **mark-based client uPnL + WS `mp`** is the correct integration pattern to document.

---

## Question 2 — Workaround with the current Price WebSocket?

### Yes — for the **price component** of unrealized PnL

This is the standard industry pattern (Binance/Bybit: mark stream + local position cache).

```
┌─────────────────────┐     once / on fill / periodic
│  Trade REST         │──── GET /futures/positions
│  (authenticated)    │     entry_price, quantity, side, trade_currency
└─────────────────────┘
           │
           ▼
┌─────────────────────┐     cache in client
│  Position cache     │     { symbol, entry, qty, side, currency, hedge_rate }
└─────────────────────┘
           │
           │     on each ticker push
           ▼
┌─────────────────────┐     wss://price.mudrex.com/api/v2/linear
│  Price WebSocket    │──── ticker@5s  →  mp (mark)
│  (public)           │     markKline@1m@btcusdt  →  c (mark close)
└─────────────────────┘
           │
           ▼
┌─────────────────────┐
│  Client computes    │──── unrealized_pnl on every mp update
│  uPnL               │
└─────────────────────┘
```

#### Subscribe (futures)

```json
{
    "id": 1,
    "method": "SUBSCRIBE",
    "params": ["ticker@5s"],
    "assets": ["btcusdt", "ethusdt"]
}
```

Use `mp` from each push — **not** `p` (LTP). Mudrex uses mark for liquidation; uPnL should align with mark.

---

### Unrealized PnL formula (client-side)

Prices in **USDT**. Quantity in **base asset**. Result in **position currency**.

**USDT margin (`trade_currency: USDT`):**

```
LONG:  uPnL = (mark_price - entry_price) × quantity
SHORT: uPnL = (entry_price - mark_price) × quantity
```

**INR margin (`trade_currency: INR`):**

```
uPnL_inr = uPnL_usdt × entry_hedge_rate
```

Use `entry_hedge_rate` from the position object (rate at entry). For live INR display matching UI exactly, confirm with engineering whether current hedge rate or entry rate is used.

#### Example

| Field | Value |
|---|---|
| Side | LONG |
| `entry_price` | `63000` USDT |
| `quantity` | `0.1` BTC |
| `mp` (WS) | `63694.2` USDT |
| `trade_currency` | USDT |

```
uPnL = (63694.2 - 63000) × 0.1 = 69.42 USDT
```

---

### Funding fees — partial workaround

Price WS does **not** stream funding. Combine three sources:

| Source | Endpoint | What you get |
|---|---|---|
| Current funding rate | Trade `GET /futures/BTCUSDT?is_symbol` | `funding_fee_perc`, `funding_interval` |
| Funding already paid | Trade `GET /futures/fee/history` | `fee_type: FUNDING` rows per symbol |
| Live mark (for notional) | Price WS `mp` | Position notional ≈ `mp × quantity` |

**Accrued funding since position open** is **not** available as a single field. Options:

1. **Sum `FUNDING` rows** from fee history since `position.created_at` (accurate for *paid* funding, lags until settlement).
2. **Estimate** next accrual: `notional × funding_fee_perc` — approximation only; may not match Mudrex settlement.
3. **Wait for account WS** — server pushes funding + uPnL together (PRD out of scope today).

**Do not** add funding to the same Price WS unless product explicitly wants a combined market+account stream (that blurs public/private boundaries).

---

### Platform / trading fees — partial workaround

Trading fees are **realized at execution**, not mark-driven.

| Fee type | Where | Nature |
|---|---|---|
| `TRANSACTION` | `GET /futures/fee/history` | Paid on open/close/SL/TP fills |
| `FUNDING` | Same | Periodic settlement |

Opening fee does **not** change with mark price — it is a sunk cost. For **net P&L display**:

```
net ≈ unrealized_pnl (from WS mp)
    - sum(TRANSACTION fees for this position's lifecycle)
    + sum(FUNDING fees — negative = rebate)
```

All from REST fee history + client uPnL. No WS shortcut for fees today.

---

## What to document for API users

### Document now (no new endpoints)

1. **No REST `unrealized_pnl`** — explain why (staleness); point to compute pattern.
2. **Price WS `mp`** — official live mark for uPnL math.
3. **Position fields required** — `entry_price`, `quantity`, `order_type`, `trade_currency`, `entry_hedge_rate`.
4. **Sample formula** — USDT + INR variants.
5. **Fee history** — how to build net P&L including `TRANSACTION` + `FUNDING`.
6. **Refresh rules** — re-fetch positions on: open, close, add-margin, partial close, leverage change.

### Document later (engineering)

1. **Account WebSocket** — `position` topic with server `unrealized_pnl` (PRD phase 2).
2. **Optional REST field** — `unrealized_pnl` on `GET /positions` if computed server-side at query time (still staler than WS unless paired with mark timestamp).

### Do not document

- REST `unrealized_pnl` as if it were live without a mark timestamp
- Index price / open interest for uPnL (not needed per product decision)

---

## Comparison matrix

| Need | Price WS today | Trade REST today | Separate uPnL WS | Account WS (future) |
|---|---|---|---|---|
| Live mark price | ✅ `mp` | ❌ stale | — | — |
| Position state | ❌ | ✅ positions | — | ✅ push on change |
| Unrealized PnL | ⚠️ client calc | ❌ not exposed | ✅ if built | ✅ server value |
| Funding paid | ❌ | ✅ fee history | ❌ | ✅ possible |
| Funding rate | ❌ | ✅ asset listing | ❌ | ✅ possible |
| Trading fees | ❌ | ✅ fee history | ❌ | ✅ possible |
| Match Mudrex UI exactly | ⚠️ approximate | ❌ | ✅ | ✅ best |

---

## Open questions (for PM / engineering)

1. **UI parity:** Must client-computed uPnL match the Mudrex app to the cent, or is mark-formula uPnL acceptable in docs?
2. **INR hedge:** Does displayed uPnL use `entry_hedge_rate` or a live INR/USDT rate?
3. **Funding in uPnL:** Does the app show uPnL **before** or **after** accrued funding — or as separate line items?
4. **Account WS timeline:** Is authenticated `position` stream on the roadmap before publishing uPnL guidance?
5. **REST convenience field:** Worth adding read-only `unrealized_pnl` on `GET /positions` (computed at request time with current mark), with documented staleness — even if WS is the recommended path?

---

## Minimal integration checklist

- [ ] On bot start: `GET /futures/positions` → build position cache
- [ ] Connect `wss://price.mudrex.com/api/v2/linear`
- [ ] `SUBSCRIBE` `ticker@5s` for symbols with open positions
- [ ] On each `mp` push: recompute uPnL per cached position
- [ ] On order fill / close: refresh position cache via REST
- [ ] For net P&L: poll or cache `GET /futures/fee/history` for `FUNDING` + `TRANSACTION`
- [ ] For funding countdown: poll asset `funding_interval` (slow cadence, e.g. every 60s)

---

## Related APIs (quick reference)

```bash
# Position state (auth)
curl -H "X-Authentication: $KEY" \
  "https://trade.mudrex.com/fapi/v1/futures/positions?trade_currency=USDT"

# Funding rate + interval (auth)
curl -H "X-Authentication: $KEY" \
  "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT?is_symbol"

# Fees paid (auth)
curl -H "X-Authentication: $KEY" \
  "https://trade.mudrex.com/fapi/v1/futures/fee/history?limit=50"

# Live mark (no auth) — WebSocket ticker@5s → mp
```
