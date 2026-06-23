# Trading API quick reference (INR)

Quick overview of all trading actions with `trade_currency` support. See [Trading in INR via API](trading-in-inr-via-api.md) for the full mental model.

**Base URL:** `https://trade.mudrex.com/fapi/v1`

**Opt-in:** Add `trade_currency=INR` (query param on GET, body field on POST/PATCH/DELETE). Defaults to `USDT`.

## Wallet management

| Action | Method | Endpoint | `trade_currency` |
|---|---|---|---|
| Check spot balance | `GET` | `/wallet/funds` | Query param |
| Check futures balance | `GET` | `/futures/funds` | Query param |
| Transfer USDT funds | `POST` | `/wallet/futures/transfer` | N/A (USDT only) |
| Transfer INR funds | `POST` | `/futures/transfers/inr` | N/A (INR only) |
| Get transactions | `GET` | `/futures/transactions` | Query param |

## Asset discovery (unchanged)

| Action | Method | Endpoint | `trade_currency` |
|---|---|---|---|
| List all assets | `GET` | `/futures` | Not applicable |
| Get asset details | `GET` | `/futures/{asset_id}` | Not applicable |

## Leverage management

| Action | Method | Endpoint | `trade_currency` |
|---|---|---|---|
| Get leverage | `GET` | `/futures/{asset_id}/leverage` | Query param |
| Set leverage | `POST` | `/futures/{asset_id}/leverage` | Body field |

## Order management

| Action | Method | Endpoint | `trade_currency` |
|---|---|---|---|
| Place order | `POST` | `/futures/{asset_id}/order` | Body field |
| View open orders | `GET` | `/futures/orders` | Query param |
| Get order details | `GET` | `/futures/orders/{order_id}` | — |
| Cancel order | `DELETE` | `/futures/orders/{order_id}` | — |
| Amend order | `PATCH` | `/futures/orders/{order_id}` | — |
| Order history | `GET` | `/futures/orders/history` | Query param |

## Position management

| Action | Method | Endpoint | `trade_currency` |
|---|---|---|---|
| View open positions | `GET` | `/futures/positions` | Query param |
| Close position | `POST` | `/futures/positions/{id}/close` | Inherited from UUID |
| Partial close | `POST` | `/futures/positions/{id}/close/partial` | Inherited from UUID |
| Reverse position | `POST` | `/futures/positions/{id}/reverse` | Inherited from UUID |
| Position history | `GET` | `/futures/positions/history` | Query param |
| Add/reduce margin | `POST` | `/futures/positions/{id}/add-margin` | Inherited from UUID |
| Set/edit SL/TP | `POST/PATCH` | `/futures/positions/{id}/riskorder` | Inherited from UUID |
| Liquidation price | `GET` | `/futures/positions/{id}/liq-price` | Query param |

## Monitoring

| Action | Method | Endpoint | `trade_currency` |
|---|---|---|---|
| Fee history | `GET` | `/futures/fee/history` | Query param |

## INR quick workflow

1. `GET /futures/funds?trade_currency=INR` — check INR futures balance
2. `POST /futures/transfers/inr` — move INR from spot to futures
3. `POST /futures/BTCUSDT/leverage?is_symbol` with `trade_currency: INR` — set leverage
4. `POST /futures/BTCUSDT/order?is_symbol` with `trade_currency: INR` — place order
5. `GET /futures/positions?trade_currency=INR` — monitor positions

## Four-wallet reference

| Wallet | Read endpoint | Transfer endpoint |
|---|---|---|
| USDT Spot | `GET /wallet/funds` | `POST /wallet/futures/transfer` |
| USDT Futures | `GET /futures/funds` | `POST /wallet/futures/transfer` |
| INR Spot | `GET /wallet/funds?trade_currency=INR` | `POST /futures/transfers/inr` |
| INR Futures | `GET /futures/funds?trade_currency=INR` | `POST /futures/transfers/inr` |
