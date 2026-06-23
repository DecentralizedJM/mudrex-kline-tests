# Changelog — INR Margin Support

Release Date: June 2026

Breaking Changes: **No**

Deprecations: **No**

## Backward compatibility guarantee

Existing API clients that do not pass `trade_currency` continue to work **unchanged**. All operations default to USDT. Responses may include new additive fields (`trade_currency`, `hedge_rate`) on positions and orders. No existing field is renamed or removed.

## Added

### `trade_currency` parameter

Optional parameter on all currency-aware endpoints. Values: `USDT` (default), `INR`.

- GET requests: query parameter `?trade_currency=INR`
- POST/PATCH/DELETE requests: JSON body field `"trade_currency": "INR"`

### INR fund transfer endpoint

- `POST /fapi/v1/futures/transfers/inr` — transfer between INR spot and INR futures wallets
- USDT transfers continue to use `POST /fapi/v1/wallet/futures/transfer`

### Transactions endpoint

- `GET /fapi/v1/futures/transactions` — retrieve futures wallet transaction history with currency, type, and status filters

### Per-(asset, currency) leverage

Leverage can be set and queried independently for the same asset in USDT and INR.

### Currency-scoped list endpoints

The following endpoints filter by `trade_currency` (default `USDT`, one currency per call):

- `GET /futures/positions`
- `GET /futures/positions/history`
- `GET /futures/orders`
- `GET /futures/orders/history`
- `GET /futures/fee/history`

### Additive response fields

| Field | Appears on | Description |
|---|---|---|
| `trade_currency` | Positions, orders, fees | `"USDT"` or `"INR"` |
| `hedge_rate` | Orders (history), positions | FX rate (INR/USDT); `1` for USDT |
| `entry_hedge_rate` | Open positions, position history | FX rate at position entry |
| `exit_hedge_rate` | Position history | FX rate at position exit |
| `gst_amount` | Fee history (INR) | GST on INR transaction fees |

## Changed

### Wallet reads

- `GET /wallet/funds` — accepts `?trade_currency=INR` for INR spot wallet
- `GET /futures/funds` — accepts `?trade_currency=INR` for INR futures wallet

### Order placement

- `POST /futures/{asset_id}/order` — accepts `trade_currency: "INR"` in body; margin debited from INR wallet

## Unchanged

- `GET /futures` — asset listing (symbols, prices remain USDT-denominated)
- `GET /futures/{asset_id}` — asset metadata
- Authentication, rate limits, error format

## Migration notes

- **No migration required.** Existing USDT-only integrations work without changes.
- To trade in INR, add `trade_currency: "INR"` to requests.
- Use `POST /futures/transfers/inr` for INR wallet transfers (not `/wallet/futures/transfer`).
- Use separate list calls per currency — responses never mix USDT and INR.

## New documentation

- [Trading in INR via API](trading-in-inr-via-api.md)
- [Quickstart (INR)](quickstart-inr.md)
- [Quick reference (INR)](quick-reference-inr.md)
- [Error reference (INR)](errors-inr.md)
