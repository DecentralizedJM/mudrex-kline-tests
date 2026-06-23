# [P0] Add server-computed `unrealized_pnl` to `GET /futures/positions`

**Type:** Engineering ticket — API enhancement
**Priority:** P0 (blocks RexAlgo live-uPnL MVP)
**Owner:** Mudrex — Futures / Position service + API layer
**Reporter:** API Trading product (productteam@mudrex.com)
**Date:** 2026-06-20
**Labels:** `futures-api` `positions` `rexalgo` `p0`
**Related:** `docs/rexalgo-upnl-problem-and-solution.md`, `docs/rexalgo-streaming-upnl-solution.md`, `docs/positions/list-positions.md`

---

## Summary

Extend open-position objects on the Trade API to return **server-computed unrealized PnL** plus the mark price and timestamp used to compute it. The value must equal what the Mudrex app shows for the same position, in the position's `trade_currency` (USDT or INR).

This is the **Phase-1 / MVP** of the RexAlgo uPnL plan. The authenticated account WebSocket (`position` topic, `UPNL_UPDATE`) is a **separate P1 ticket** and is explicitly **out of scope** here.

---

## Background / why

RexAlgo is the source of truth for its users and must show open positions with **live uPnL that matches Mudrex exactly**. Today that is blocked by missing API capability, not by Rex's UI:

- `GET /fapi/v1/futures/positions` returns `entry_price`, `quantity`, side, margin — **but no `unrealized_pnl`**.
- The public Price WebSocket (`price.mudrex.com`) streams `p` (LTP) and `mp` (mark) but has **no position size and no user context**.
- Rex computing uPnL client-side from `mp × quantity` is **not acceptable** — it drifts from the app on INR hedge, rounding, and funding treatment, and Rex brands uPnL as Mudrex-official.

**Root cause:** Mudrex does not expose server-computed `unrealized_pnl` on positions. Once REST returns it, Rex can poll every 1–2s and fan out to its users for a correct MVP while the account WS is built.

---

## Scope

**In scope**

- Add `mark_price`, `unrealized_pnl`, `computed_at` (and optional `unrealized_pnl_perc`) to **open** position objects.
- Endpoints:
  - `GET /fapi/v1/futures/positions` (USDT)
  - `GET /fapi/v1/futures/positions?trade_currency=INR` (INR)
  - Single-position GET, if one exists, for parity.
- uPnL computed by the **same code path / formula as the Mudrex app** open-positions screen.
- Documentation of the formula, funding treatment, and INR hedge rule.

**Out of scope**

- Authenticated account WebSocket and the `position` / `UPNL_UPDATE` stream (P1 — separate ticket).
- Position **history** endpoint (already returns realized `pnl`; no change).
- Any change to the public Price WebSocket or `price.mudrex.com`.

---

## Requirements

### New response fields (open positions only)

| Field | Type | Required | Description |
|---|---|---|---|
| `mark_price` | string | Yes | Mark price (USDT) used to compute this uPnL |
| `unrealized_pnl` | string | Yes | **Authoritative** server-computed uPnL, in the position's `trade_currency` |
| `computed_at` | integer | Yes | Unix seconds — when Mudrex computed the value |
| `unrealized_pnl_perc` | string | Optional | uPnL as % (define basis: initial margin vs notional) |

Field naming follows the live Trade API style (snake_case, string-typed numerics) already used by the positions response.

### Behaviour

- Recompute `unrealized_pnl` on each internal **mark tick**, not only when REST is polled — so a poll returns a fresh value with a current `computed_at`.
- Closed/liquidated positions are unchanged (history keeps realized `pnl`).
- `unrealized_pnl` is signed (negative when losing).

### USDT example

```json
{
    "id": "019ecc52-2f95-7ab5-8682-c3a0f43ccda6",
    "symbol": "BTCUSDT",
    "order_type": "LONG",
    "entry_price": "63000",
    "quantity": "0.1",
    "trade_currency": "USDT",
    "status": "OPEN",
    "mark_price": "63694.2",
    "unrealized_pnl": "69.42",
    "unrealized_pnl_perc": "1.10",
    "computed_at": 1781935200
}
```

### INR example

INR positions carry `entry_hedge_rate`; `entry_price`/`mark_price` are in USDT but `unrealized_pnl` is in INR.

```json
{
    "id": "019ecc52-2f95-7ab5-8682-c3a0f43ccda6",
    "symbol": "SOMIUSDT",
    "order_type": "LONG",
    "entry_price": "0.11442",
    "quantity": "43.8",
    "trade_currency": "INR",
    "entry_hedge_rate": "96",
    "status": "OPEN",
    "mark_price": "0.11510",
    "unrealized_pnl": "28.64",
    "computed_at": 1781935200
}
```

---

## Computation rules (must be documented in API docs)

Baseline price component:

```
LONG:  (mark_price - entry_price) × quantity
SHORT: (entry_price - mark_price) × quantity
```

The following must be **decided and written into the docs** so Rex applies exactly one rule:

1. **Funding** — Is accrued funding included in `unrealized_pnl`, or is it price-only and surfaced separately? (Trade API exposes `funding_fee_perc` / fee history; Rex needs one definitive rule.)
2. **INR hedge** — Is INR uPnL converted using `entry_hedge_rate` (frozen at entry) or the live FX rate? Must match the app.
3. **Rounding / decimals** — Decimal places and rounding mode must match the app for both USDT and INR.

---

## Open questions (need answers before/with implementation)

| # | Question | Owner |
|---|---|---|
| 1 | Does `unrealized_pnl` include accrued funding or is it price-only? | Mudrex product |
| 2 | INR uPnL: `entry_hedge_rate` or live FX? | Mudrex engineering |
| 3 | Target ship date for REST `unrealized_pnl`? | Mudrex |
| 4 | Is there a single-position GET to mirror, or list only? | Mudrex engineering |
| 5 | `unrealized_pnl_perc` basis — initial margin or notional? (or drop for v1) | Mudrex product |

---

## Acceptance criteria

- [ ] `GET /fapi/v1/futures/positions` returns `mark_price`, `unrealized_pnl`, `computed_at` on every **open** position (USDT).
- [ ] `GET /fapi/v1/futures/positions?trade_currency=INR` returns the same fields with `unrealized_pnl` in INR.
- [ ] `unrealized_pnl` **matches the Mudrex app** for the same open position to the displayed decimal place — verified for both a USDT and an INR position.
- [ ] Value is correct for both **LONG and SHORT** (sign and magnitude).
- [ ] `computed_at` reflects a recent mark tick (not the position open time); repeated polls a few seconds apart return updated `mark_price` / `unrealized_pnl` as the mark moves.
- [ ] Funding treatment and INR hedge rule are documented in the public API docs.
- [ ] No change to closed/liquidated positions or the history endpoint.

## Test plan

1. Open a BTCUSDT LONG via API; poll `GET /futures/positions` every ~2s for 60s; confirm `unrealized_pnl` tracks the mark and equals the app screen throughout.
2. Repeat for a SHORT and for an INR position (`trade_currency=INR`) to validate sign and hedge handling.
3. Diff API `unrealized_pnl` vs app value at several timestamps; assert match to displayed precision.
4. Add to the 360 regression suite (`testing/run_price_360.sh` companion / Trade API tests) so the field and parity are covered going forward.

---

## Dependencies & rollout

- **Unblocks:** RexAlgo P0 — poll positions 1–2s → fan-out via Rex WS (`docs/rexalgo-upnl-problem-and-solution.md` §5.1). Rex must display the Mudrex value only — never recompute.
- **Followed by (separate P1 ticket):** authenticated account WebSocket on Trade API with `position` topic and `UPNL_UPDATE` events, so Rex can switch from polling to push.
- **Backward compatible:** additive fields only; existing consumers unaffected.
