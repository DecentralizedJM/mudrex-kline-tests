# Trading in INR via API

INR-margined futures trading is now available on the Mudrex Futures API. This page explains how INR margin works, how it differs from USDT margin, and how to opt in without breaking existing integrations.

## Four-wallet model

Mudrex maintains four separate wallets under one API key:

| Wallet | Currency | API access |
|---|---|---|
| Spot | USDT | `GET /wallet/funds` (default) |
| Futures | USDT | `GET /futures/funds` (default) |
| Spot | INR | `GET /wallet/funds?trade_currency=INR` |
| Futures | INR | `GET /futures/funds?trade_currency=INR` |

Transfers move funds **within the same currency only**:

- USDT spot ↔ USDT futures via `POST /wallet/futures/transfer`
- INR spot ↔ INR futures via `POST /futures/transfers/inr`

Cross-currency transfers (INR spot → USDT futures) are **not supported** via API. Convert via the Mudrex UI.

## Opting in with `trade_currency`

Add `trade_currency` to operate in INR. When omitted, all endpoints default to **USDT** (backward compatible).

| Request type | How to pass `trade_currency` |
|---|---|
| GET | Query parameter: `?trade_currency=INR` |
| POST / PATCH / DELETE | JSON body field: `"trade_currency": "INR"` |

Supported values: `USDT` (default), `INR`. Any other value returns `400 Invalid trade currency`.

## What stays USDT vs what becomes INR

| Concept | Currency behavior |
|---|---|
| Asset symbol (`BTCUSDT`, `ETHUSDT`) | Unchanged — same contracts for both margin currencies |
| Contract price, tick size, lot size, min notional | Always USDT |
| Order price, entry price, liquidation price | Always USDT |
| Quantity / quantity step | Base asset (e.g., BTC) — no currency dimension |
| Wallet balance, locked margin | Wallet's own currency (INR or USDT) |
| Margin debited on order | Position's trade currency |
| Realized / unrealized PnL | Position's trade currency |
| Trading and funding fees | Position's trade currency |
| FX rate (INR/USDT) | Returned as `hedge_rate` on INR orders and positions |

## One currency per list call

List endpoints return **one currency per request**. They never mix USDT and INR in a single response.

| Endpoint | Default (no param) | With `trade_currency=INR` |
|---|---|---|
| `GET /futures/positions` | USDT positions only | INR positions only |
| `GET /futures/orders` | USDT orders only | INR orders only |
| `GET /futures/orders/history` | USDT history only | INR history only |
| `GET /futures/positions/history` | USDT history only | INR history only |

Each position and order in the response includes a `trade_currency` field (`"USDT"` or `"INR"`).

## Independent leverage per (asset, currency)

Leverage is stored independently per asset **and** per currency. Setting leverage for `BTCUSDT` in INR does not affect `BTCUSDT` in USDT.

```bash
# Set INR leverage
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT/leverage?is_symbol" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{"margin_type": "ISOLATED", "leverage": "2", "trade_currency": "INR"}'

# Set USDT leverage (independent)
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT/leverage?is_symbol" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{"margin_type": "ISOLATED", "leverage": "1.5", "trade_currency": "USDT"}'
```

## Concurrent positions on the same symbol

A user can hold `BTCUSDT` in INR futures and `BTCUSDT` in USDT futures simultaneously. These are separate positions with separate UUIDs, isolated margin pools, and independent liquidation.

## Backward compatibility

Existing API clients that do not pass `trade_currency` continue to work unchanged:

- All operations default to USDT
- USDT-only list calls return only USDT positions/orders
- Responses may include new additive fields (`trade_currency`, `hedge_rate`) on positions and orders

## Limitations

- No INR ↔ USDT conversion via API
- No INR deposit or withdrawal endpoints
- No cross-currency wallet transfers
- Asset listing (`GET /futures`) is not currency-filtered — symbols and prices remain USDT-denominated

## Quick workflow

1. Check INR futures balance → `GET /futures/funds?trade_currency=INR`
2. Transfer INR spot → futures if needed → `POST /futures/transfers/inr`
3. Set leverage → `POST /futures/{symbol}/leverage?is_symbol` with `trade_currency: INR`
4. Place order → `POST /futures/{symbol}/order?is_symbol` with `trade_currency: INR`
5. Monitor → `GET /futures/positions?trade_currency=INR`

See [Quickstart (INR)](quickstart-inr.md) for a complete walkthrough.
