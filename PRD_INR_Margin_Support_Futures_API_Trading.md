# PRD: INR Margin Support for Futures API Trading

## 1. Overview

INR Futures is live on the Mudrex UI. Users trade the same USDT-margined linear perpetual contracts (BTCUSDT, ETHUSDT, etc.) using INR as the margin and settlement currency, via a server-side conversion rate. Contracts, prices, and tick semantics remain USDT-denominated; only the margin wallet and the currency PnL is realized in change.

This PRD brings the same capability to the API. The change is additive: every API capability that today operates in USDT gains an optional way to operate in INR. Existing API clients see no behavior change unless they opt in.

## 2. Problem and Objective

### 2.1 Problem

The Mudrex UI supports INR-margined futures. The API does not. API users who want to trade INR futures today must either use the UI (defeating the purpose of API access) or manually convert INR to USDT via the UI's spot flow before trading via API.

This blocks three groups:

- Existing API users who hold balances primarily in INR.
- Traditional-market traders onboarded by the partnership team, who expect to operate in INR end-to-end.
- Users migrating from Binance and Bybit who treat native-currency settlement as table-stakes.

### 2.2 Objective

Allow any Mudrex API user to read INR balances, transfer between INR wallets, place and manage futures orders and positions using INR margin, and set per-asset leverage independently for INR and USDT — without breaking any existing USDT-only API integration.

### 2.3 Out of scope

| Excluded | Reason |
|---|---|
| INR ↔ USDT conversion (spot buy/sell) | Mudrex API does not expose spot trading. Users convert via UI. |
| INR deposit / withdrawal endpoints | Out of API scope entirely. |
| Cross-currency wallet transfers (e.g., INR spot → USDT futures) | Requires a spot conversion, not available via API. |
| Changes to asset listing, kline, ticker pricing | Contract prices and specs remain USDT-denominated for both currencies. |

## 3. Mental Model — What Is Currency-Aware, What Isn't

| Concept | Currency behavior |
|---|---|
| Asset symbol (e.g., BTCUSDT) | Unchanged regardless of margin currency. |
| Contract price, tick size, lot size, min notional | Always USDT. |
| Order price, entry price, liquidation price | Always USDT. These are price levels on the underlying USDT-quoted contract; they are not converted. |
| Quantity, quantity step | Always in the base asset (e.g., BTC). No currency dimension. |
| Wallet balance, available balance, locked margin | In the wallet's own currency. |
| Margin debited on order placement | In the currency the user trades in. |
| Realized and unrealized PnL | In the currency the position was opened in. |
| Funding fees, trading fees | Charged in the position's currency. |
| FX rate (INR/USDT) | Surfaced in API responses for INR-margin operations, parity with what the app shows. |

## 4. User Personas

| Persona | What this enables |
|---|---|
| Indian retail API trader holding INR | Programmatic futures trading without converting to USDT first. |
| Traditional-market trader onboarded via partnership | Native INR balances, PnL, and positions via API. |
| Existing USDT API user | No change. Existing scripts work unchanged. |
| Multi-currency bot operator | Operates on both currencies through one API key. |

## 5. User Stories

- As an API user holding INR margin, I want to transfer funds between my INR spot and INR futures wallets via API, so that I can fund and defund my INR futures position without using the UI.
- As an API user holding INR margin, I want to place, modify, and close futures orders that draw margin from my INR futures wallet, so that my entire trading workflow runs in INR end-to-end.
- As an API user, I want to query my INR futures wallet balance, my INR positions, and my INR order history through the API, so that my reporting and risk logic see the same state as the UI.
- As an API user, I want to set per-asset leverage independently for INR and USDT, so that I can run different risk profiles on the same symbol across currencies.
- As an existing USDT-only API user, I want my existing scripts to continue working without modification, so that the addition of INR support does not force a migration. Retrieval is per-currency: the operator reads each position through a separate currency-scoped call; no single call returns both.
- As a multi-currency bot operator, I want to hold a position in BTCUSDT in INR futures and a separate position in BTCUSDT in USDT futures simultaneously, so that I can run currency-isolated strategies on the same symbol. (Note: this is not hedge mode; the positions are isolated by virtue of being on different wallets.)

## 6. Functional Requirements

| Capability | Acceptance criteria |
|---|---|
| Read INR spot wallet funds | API user can read the INR spot wallet with the same conceptual fields as the USDT spot wallet (total, invested, withdrawable, etc.), denominated in INR. A user who has never used INR sees a valid zero-balance response, not an error. |
| Read INR futures wallet funds | API user can read the INR futures wallet with the same conceptual fields as the USDT futures wallet (balance, locked margin, first-time-user flag, etc.), denominated in INR. Never-used returns zero balances, not an error. |
| Transfer between INR spot and INR futures wallets | API user can move funds between INR spot and INR futures in the same operation that today moves USDT between USDT spot and USDT futures. Insufficient INR balance returns the existing insufficient-balance behavior. |
| Place a futures order with INR margin | API user can submit an order whose margin is debited from the INR futures wallet. The response indicates the order's currency. Order price, stoploss, takeprofit remain USDT. Order quantity remains in the base asset. Insufficient INR margin returns the existing insufficient-balance behavior. |
| Set leverage per (asset, currency) | API user can set leverage for BTCUSDT in INR independently of BTCUSDT in USDT. Setting one does not affect the other. Both are queryable. Setting leverage in a currency the user has never traded is permitted; it takes effect on the next order in that (asset, currency). |
| List positions, optionally filtered by currency | API user lists positions for one currency per call. Currency is an explicit parameter; when omitted it defaults to USDT. A response never mixes currencies. Each position indicates its currency. |
| List orders and order history, optionally filtered by currency | Same shape and default as positions: one currency per call, defaults to USDT when omitted, never mixed. Each order indicates its currency. |
| Manage existing positions | API user operates on a position by its UUID. Margin amounts (e.g., add-margin) are in the position's currency. Liquidation price remains USDT. |
| FX rate visibility | For INR-margin operations, the API exposes the conversion rate in responses where the app already exposes it. |
| Backward compatibility | Existing requests that don't opt into INR behave exactly as today. Responses to those requests gain only additive fields; no field is renamed or removed. |

## 7. Scope

### 7.1 In scope

- INR equivalent of every USDT-margin futures capability listed in §6
- Per-(asset, currency) leverage
- Per-(symbol, currency) positions
- Currency filtering on list endpoints (USDT or INR, one currency per call; defaults to USDT when omitted)

### 7.2 Out of scope

- Asset listing changes
- Kline / ticker / WebSocket market data changes
- Spot trading via API
- Cross-currency transfers (INR ↔ USDT in one operation)

## 8. Edge Cases

| Edge case | Expected behavior |
|---|---|
| Old API client calls positions list with both USDT and INR positions | Returns USDT positions only unless `trade_currency=INR` |
| Old API client calls order list with both USDT and INR orders | Returns USDT orders only unless `trade_currency=INR` |
| INR transfer with empty source wallet | Standard insufficient-balance behavior |
| Unsupported currency value | Standard invalid-request behavior naming USDT, INR |
| Open INR position + USDT order on same symbol | Independent; isolated by wallet |
| Set USDT leverage, query INR leverage | Returns INR value (default if never set), independent of USDT |
| Legacy positions/orders | Backfilled with USDT currency tag |
| Query INR futures balance never deposited | Zero balances + first_time_user flag, not error |
| Same-symbol concurrent positions in both currencies | Each liquidates independently |
| Add margin in wrong currency | Not possible — UUID inherits position currency |

## 9. Engineering Notes

- Backward compatibility: existing USDT-only requests must produce identical responses modulo additive fields
- Naming conventions follow existing API; new fields are additive except `/wallet` endpoints for balances/transfers
- Per-key isolation unchanged; INR and USDT under same API key
- Rate limits shared across currencies
- FX rate handling inherited from app

## 10. Non-Functional Requirements

- Latency: INR operations not measurably slower than USDT
- Backward compatibility verification via automated regression
- Documentation parity: every affected page shows both USDT and INR examples

## 11. Success Metrics

| Metric | Target |
|---|---|
| API keys with at least one INR operation/week | >50% of weekly active traders |
| Share of API trading volume in INR vs USDT | >50% of daily API volume |
| Partnership-onboarded users trading INR via API | >60% more than current rate |
| Support tickets tagged currency/inr-futures per 100 active keys | <2/month (current 5/month) |
| Backward-compatibility regressions | Zero |

## 12. Impact Analysis

### 12.1 Change Impact

- Existing USDT-only endpoints: additive only; default unchanged (USDT implicit)
- New surface: INR wallet reads, INR transfers, INR-margin order/position lifecycle, per-(asset, currency) leverage, currency-scoped list endpoints
- Data backfill: legacy positions/orders tagged USDT
- Client migration: none; opt-in via `trade_currency`

## 13. Documentation Deliverables

| Surface | Required artifact |
|---|---|
| Each affected API doc page | Dual examples (USDT and INR). Updated parameter list and response shape. |
| New page: "Trading in INR via API" | Four-wallet model, one-currency-per-list-call, defaults to USDT |
| Changelog | Prominent backward-compatibility note |
| Error reference | Any new error codes engineering defines |

## Timeline

- PRD reviewed and approved: May 19, 2026
- T-shirt size: S, done May 27, 2026
