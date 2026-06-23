# RexAlgo × Mudrex — Unrealized PnL Problem & Solution

**Date:** 2026-06-20  
**Status:** Proposed  
**Audience:** Mudrex engineering, RexAlgo product & engineering

---

## 1. Problem statement

**RexAlgo cannot show live unrealized PnL (uPnL) on open futures positions.**

RexAlgo is the **source of truth** for its users — they expect to see open positions and **dynamic, accurate uPnL** inside Rex, matching what they would see on Mudrex.

Today this is **blocked by missing API capability on Mudrex**, not by a RexAlgo UI limitation.

### What exists today

| Surface | Provides | Missing |
|---|---|---|
| `GET /fapi/v1/futures/positions` | `entry_price`, `quantity`, side, margin, … | **`unrealized_pnl`** |
| Price WebSocket `ticker@5s` | Live `p` (LTP) + `mp` (mark) | Position size, user context, uPnL |
| `GET /futures/positions/history` | Realized `pnl` (closed only) | Open-position uPnL |

### Why Rex cannot solve this alone

Rex could estimate uPnL with:

```
(mark_price - entry_price) × quantity   (LONG)
```

using Price WS `mp` + cached position from REST. **This is not acceptable** for Rex because:

1. It may **not match Mudrex app** uPnL (INR hedge, rounding, funding treatment).
2. Rex brands itself as authoritative — users must see **Mudrex-official** numbers.
3. Two REST calls (position + mark) at different times still produce **stale/wrong** values.

**Root cause:** Mudrex does not expose server-computed `unrealized_pnl` on positions, and has no **private stream** that pushes it per user.

---

## 2. Goal

| Requirement | Detail |
|---|---|
| Show open positions in Rex | Symbol, side, size, entry, margin — already possible via REST |
| Show **live uPnL** per position | Updates as mark moves (every few seconds) |
| **Match Mudrex** | Same value as Mudrex app for that position |
| Scale | Many Rex users, each with their own Mudrex API key |

---

## 3. Recommended solution (both sides)

```text
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│  Rex user    │ ◄─WS─── │  RexAlgo     │ ◄─WS─── │   Mudrex     │
│  (browser)   │         │  backend     │         │  account WS  │
└──────────────┘         └──────┬───────┘         └──────────────┘
                                │
                                │ REST (snapshot + reconcile)
                                ▼
                         GET /futures/positions
                         (with unrealized_pnl)
```

**Principle:** Mudrex **computes** uPnL. Rex **displays and streams** it. Rex never recalculates.

---

## 4. What Mudrex must build

### 4.1 Phase 1 — REST fields (MVP, ship first)

Extend open position objects on:

`GET /fapi/v1/futures/positions`  
`GET /fapi/v1/futures/positions?trade_currency=INR`

**Add fields:**

| Field | Type | Description |
|---|---|---|
| `mark_price` | string | Mark price in USDT used for uPnL |
| `unrealized_pnl` | string | Server-computed uPnL in `trade_currency` |
| `computed_at` | integer | Unix seconds — when Mudrex calculated this |

**Example:**

```json
{
    "id": "019ecc52-2f95-7ab5-8682-c3a0f43ccda6",
    "symbol": "BTCUSDT",
    "order_type": "LONG",
    "entry_price": "63000",
    "quantity": "0.1",
    "trade_currency": "USDT",
    "mark_price": "63694.2",
    "unrealized_pnl": "69.42",
    "computed_at": 1781935200,
    "status": "OPEN"
}
```

**Acceptance criteria:**
- `unrealized_pnl` matches Mudrex app for the same open position (USDT and INR).
- Document whether funding is included in uPnL or shown separately.
- Document INR hedge rule (`entry_hedge_rate` vs live rate).

**Enables Rex:** Poll every 1–2 seconds → near-live uPnL in Rex UI (good MVP).

---

### 4.2 Phase 2 — Account WebSocket (target, true streaming)

New **authenticated** WebSocket on Trade API (not public Price WS):

```text
wss://trade.mudrex.com/fapi/v1/ws
```

Auth: user API key (same as REST).

**Subscribe:**

```json
{ "id": 1, "method": "SUBSCRIBE", "params": ["position"] }
```

**Push events:**

| Event | When |
|---|---|
| `SNAPSHOT` | On subscribe — all open positions with uPnL |
| `UPNL_UPDATE` | Mark moved — new `unrealized_pnl` |
| `POSITION_OPENED` | New position |
| `POSITION_CHANGED` | Size, margin, leverage, SL/TP change |
| `POSITION_CLOSED` | Remove from UI |

**Example push:**

```json
{
    "stream": "position",
    "data": {
        "event": "UPNL_UPDATE",
        "id": "019ecc52-2f95-7ab5-8682-c3a0f43ccda6",
        "symbol": "BTCUSDT",
        "unrealized_pnl": "69.80",
        "mark_price": "63698.0",
        "computed_at": 1781935205
    }
}
```

**Acceptance criteria:**
- Push at mark cadence (≥ every 5s for active symbols).
- Rex receives updates without polling.
- Connection limits documented (per API key).

**Why not use public Price WS?** It has `p` and `mp` but no position data and no per-user uPnL. Fine for charts; **not** for official position uPnL.

---

### 4.3 Mudrex delivery summary

| Item | Priority | Effort (indicative) |
|---|---|---|
| `unrealized_pnl` on REST positions | **P0** | Backend — position service + API layer |
| Document uPnL formula / INR rules | **P0** | Docs |
| Account WebSocket + `position` topic | **P1** | New WS service |
| WS auth + connection limits | **P1** | Infra |

---

## 5. What RexAlgo must build

Regardless of Mudrex phase, Rex owns the **user-facing stream** and **key management**.

### 5.1 Phase 1 — REST polling (when Mudrex ships REST fields)

| # | Rex build | Detail |
|---|---|---|
| 1 | Secure API key storage | One Mudrex key per Rex user, server-side only |
| 2 | Position loader | `GET /positions` on page open (USDT + INR if needed) |
| 3 | uPnL poller | Every 1–2s while positions page is open |
| 4 | Rex → user WebSocket | Fan-out `unrealized_pnl` updates to Rex UI |
| 5 | Post-trade refresh | Re-fetch positions immediately after Rex places/closes orders |
| 6 | Display rule | Show `unrealized_pnl` from Mudrex only — never client math |

**Rex UI message:**

```json
{
    "type": "position.upnl",
    "position_id": "019ecc52-...",
    "symbol": "BTCUSDT",
    "unrealized_pnl": "69.42",
    "mark_price": "63694.2",
    "computed_at": 1781935200
}
```

---

### 5.2 Phase 2 — Mudrex account WS (when Mudrex ships WS)

| # | Rex build | Detail |
|---|---|---|
| 1 | Mudrex WS client | Connect with user's API key |
| 2 | Subscribe `position` | Per active user |
| 3 | Event handler | `UPNL_UPDATE` → update cache → fan-out to Rex UI |
| 4 | Reconnect logic | Backoff + resubscribe; fallback to REST poll |
| 5 | Connection lifecycle | Open WS when user views positions; close when idle |
| 6 | Reconcile | Periodic `GET /positions` every 60s as safety net |

**Replace** high-frequency REST polling with WS pushes. Keep REST for initial snapshot and reconciliation.

---

### 5.3 Rex delivery summary

| Item | Depends on | Priority |
|---|---|---|
| Position page + REST integration | Today (no uPnL yet) | Done / existing |
| uPnL poller + Rex WS fan-out | Mudrex REST fields | **P0** |
| Mudrex account WS client | Mudrex account WS | **P1** |
| QA: Rex uPnL vs Mudrex app | Mudrex REST fields | **P0** |

---

## 6. What NOT to do

| Approach | Verdict |
|---|---|
| Rex computes uPnL from Price WS `mp` | ❌ Will not match Mudrex app |
| Document client-side formula as official uPnL | ❌ Rex requirement is Mudrex parity |
| Put uPnL on public `price.mudrex.com` WS | ❌ No user/position context |
| Expose Mudrex API key in Rex browser | ❌ Security |
| Wait forever for WS — skip REST fields | ❌ Blocks Rex MVP for months |

**Price WebSocket remains useful for:** live `p` (LTP) and `mp` (mark) on charts and tickers — not for authoritative uPnL.

---

## 7. Timeline proposal

```text
Week 0   Problem confirmed (this doc)
Week 1–2 Mudrex: unrealized_pnl on GET /positions
Week 2–3 Rex: poller + Rex WS fan-out → MVP live uPnL in Rex
Week 4+  Mudrex: account WebSocket position topic
Week 5+  Rex: switch from poll to Mudrex WS push
```

---

## 8. Open questions (need answers before build)

| # | Question | Owner |
|---|---|---|
| 1 | Does `unrealized_pnl` include accrued funding or is it price-only? | Mudrex product |
| 2 | INR uPnL: `entry_hedge_rate` or live FX? | Mudrex engineering |
| 3 | Target REST ship date for `unrealized_pnl`? | Mudrex |
| 4 | Account WS ETA? | Mudrex |
| 5 | Max WS connections per API key? | Mudrex |
| 6 | Rex: USDT-only first or INR positions day one? | Rex product |

---

## 9. One-page summary

| | |
|---|---|
| **Problem** | Rex cannot show uPnL — Mudrex API does not expose it |
| **Mudrex fix (P0)** | Add `unrealized_pnl`, `mark_price`, `computed_at` to open positions REST |
| **Mudrex fix (P1)** | Account WebSocket `position` stream with live uPnL pushes |
| **Rex fix (P0)** | Poll Mudrex REST → fan-out to Rex users via Rex WebSocket |
| **Rex fix (P1)** | Subscribe to Mudrex account WS → relay to users |
| **Do not** | Client-side uPnL from public Price WS |
| **Price WS role** | Live LTP (`p`) + mark (`mp`) for charts — separate from uPnL |

---

## Related documents

- [`rexalgo-streaming-upnl-solution.md`](rexalgo-streaming-upnl-solution.md) — technical architecture detail
- [`unrealized-pnl-price-websocket-strategy.md`](unrealized-pnl-price-websocket-strategy.md) — why Price WS alone is insufficient
- [`futures-klines-and-price-websocket.md`](futures-klines-and-price-websocket.md) — Price API reference
