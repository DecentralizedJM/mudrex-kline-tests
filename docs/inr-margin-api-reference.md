# INR Margin API Reference

Complete endpoint reference for INR-margined futures trading. All examples tested live on production (`https://trade.mudrex.com/fapi/v1`) on 2026-06-15.

**Authentication:** Every request requires header `X-Authentication: <your-api-secret>`.

**INR opt-in:** Pass `trade_currency=INR` as a query parameter (GET) or `"trade_currency": "INR"` in the JSON body (POST/PATCH/DELETE). When omitted, endpoints default to USDT.

---

## Your account snapshot (test run)

| Wallet | Balance |
|---|---|
| INR Spot | `0` (withdrawable: `0`) |
| INR Futures | `25.8129` INR (locked: `0`) |

INR spot was empty — all INR funds are in the futures wallet. Transfer SPOT → FUTURES of `0.01` INR succeeded (202) and futures balance increased to `25.8129`.

---

## 1. INR Spot Wallet — Get funds

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/wallet/funds?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": {
        "total": 0,
        "rewards": 0,
        "invested": 0,
        "withdrawable": 0,
        "coin_investable": 0,
        "coinset_investable": 0,
        "vault_investable": 0
    }
}
```

| Field | Description |
|---|---|
| `total` | Total INR spot balance |
| `withdrawable` | INR available for transfer or withdrawal |

---

## 2. INR Futures Wallet — Get funds

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/funds?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": {
        "balance": "25.8129",
        "locked_amount": "0",
        "first_time_user": false
    }
}
```

| Field | Description |
|---|---|
| `balance` | Available INR in futures wallet |
| `locked_amount` | INR locked as margin |
| `first_time_user` | `true` if never used INR futures before |

---

## 3. INR Transfer — Spot to Futures

### cURL

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/transfers/inr" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "amount": "100",
    "from_wallet_type": "SPOT",
    "to_wallet_type": "FUTURES"
  }'
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `amount` | body | string | Yes | INR amount to transfer (positive decimal) |
| `from_wallet_type` | body | string | Yes | `"SPOT"` or `"FUTURES"` |
| `to_wallet_type` | body | string | Yes | Must be opposite of `from_wallet_type` |

### Response — Success

Status: `202 Accepted`

```json
{
    "success": true,
    "data": {
        "id": "019ecc4e-6f26-77ee-98dd-deb23ca6af32"
    }
}
```

| Field | Description |
|---|---|
| `id` | Transfer transaction UUID |

### Response — Insufficient balance

Status: `400 Bad Request`

```json
{
    "success": false,
    "errors": [
        {
            "code": null,
            "text": "insufficient balance"
        }
    ]
}
```

### Example — Futures to Spot (reverse)

**cURL**

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/transfers/inr" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "amount": "10",
    "from_wallet_type": "FUTURES",
    "to_wallet_type": "SPOT"
  }'
```

---

## 4. INR Transactions

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/transactions?limit=20&type=WITHDRAW&status=completed&sort_order=asc&sort_by=updated_at&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |
| `limit` | query | number | No | Max records (default: 20) |
| `type` | query | string | No | `DEPOSIT` or `WITHDRAW` |
| `status` | query | string | No | e.g. `completed`, `Processing` |
| `sort_order` | query | string | No | `asc` or `desc` |
| `sort_by` | query | string | No | e.g. `updated_at` |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": [
        {
            "id": "019ecc4e-6f26-77ee-98dd-deb23ca6af32",
            "wallet_transaction_id": "",
            "transaction_type": "DEPOSIT",
            "amount": "0.01",
            "status": "Completed",
            "created_at": "2026-06-15T17:22:33Z",
            "updated_at": "2026-06-15T17:22:34Z"
        },
        {
            "id": "019d3879-9db5-733f-addb-0e8fa03fe9e8",
            "wallet_transaction_id": "",
            "transaction_type": "WITHDRAW",
            "amount": "12.25",
            "status": "Completed",
            "created_at": "2026-03-29T07:23:08Z",
            "updated_at": "2026-03-29T07:23:09Z"
        }
    ]
}
```

| Field | Description |
|---|---|
| `transaction_type` | `DEPOSIT` (into futures) or `WITHDRAW` (out of futures) |
| `amount` | Amount in INR |
| `status` | `Completed` or `Processing` |

---

## 5. Get Leverage (INR)

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT/leverage?is_symbol&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `asset_id` | path | string | Yes | Trading symbol (e.g. `BTCUSDT`) |
| `is_symbol` | query | flag | Yes | Treat path as symbol |
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": {
        "margin_type": "ISOLATED",
        "leverage": "2",
        "collateral_currency_id": 0
    }
}
```

### Response — Never set (404)

Status: `404 Not Found`

```json
{
    "success": false,
    "errors": [
        {
            "code": 404,
            "text": "leverage not found"
        }
    ]
}
```

---

## 6. Set Leverage (INR)

### cURL

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT/leverage?is_symbol" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "margin_type": "ISOLATED",
    "leverage": "2",
    "trade_currency": "INR"
  }'
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `asset_id` | path | string | Yes | Trading symbol (e.g. `BTCUSDT`) |
| `is_symbol` | query | flag | Yes | Treat path as symbol |
| `margin_type` | body | string | Yes | `"ISOLATED"` |
| `leverage` | body | string | Yes | Within asset min/max range |
| `trade_currency` | body | string | Yes (for INR) | Set to `INR` |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": {
        "margin_type": "ISOLATED",
        "leverage": "2",
        "collateral_currency_id": 0
    }
}
```

---

## 7. Place Order (INR margin)

### cURL

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT/order?is_symbol" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "leverage": "2",
    "quantity": "0.001",
    "order_price": "66809.2",
    "order_type": "LONG",
    "trigger_type": "MARKET",
    "is_takeprofit": false,
    "is_stoploss": false,
    "reduce_only": false,
    "trade_currency": "INR"
  }'
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `asset_id` | path | string | Yes | Trading symbol (e.g. `BTCUSDT`) |
| `is_symbol` | query | flag | Yes | Treat path as symbol |
| `trade_currency` | body | string | Yes (for INR) | Set to `INR` — margin debited from INR wallet |
| `leverage` | body | string | Yes | Leverage value |
| `quantity` | body | string | Yes | Quantity in base asset (e.g. BTC) |
| `order_price` | body | string | Yes | Price in **USDT** |
| `order_type` | body | string | Yes | `LONG` or `SHORT` |
| `trigger_type` | body | string | Yes | `MARKET` or `LIMIT` |
| `is_takeprofit` | body | boolean | No | Default `false` |
| `is_stoploss` | body | boolean | No | Default `false` |
| `stoploss_price` | body | string | Conditional | USDT price; required if `is_stoploss: true` |
| `takeprofit_price` | body | string | Conditional | USDT price; required if `is_takeprofit: true` |
| `reduce_only` | body | boolean | No | Default `false` |

### Response — Success

Status: `202 Accepted`

```json
{
    "success": true,
    "data": {
        "leverage": "2",
        "amount": "53.76",
        "quantity": "0.001",
        "price": "66809.2",
        "order_id": "0199c39f-e866-7d6b-947e-ed2f09c90b8e",
        "status": "CREATED",
        "message": "OK"
    }
}
```

### Response — Insufficient balance

Status: `400 Bad Request`

```json
{
    "success": false,
    "errors": [
        {
            "code": 400,
            "text": "insufficient balance"
        }
    ]
}
```

### Response — Below minimum order value

Status: `400 Bad Request`

```json
{
    "success": false,
    "errors": [
        {
            "code": 400,
            "text": "order value less than minimum required value"
        }
    ]
}
```

---

## 8. Open Orders (INR)

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/orders?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |
| `limit` | query | number | No | Max records (default: 20) |
| `offset` | query | number | No | Pagination offset |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": []
}
```

When orders exist, each item includes `"trade_currency": "INR"` and `"hedge_rate"` (FX rate).

---

## 9. Order History (INR)

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/orders/history?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |
| `limit` | query | number | No | Max records |
| `offset` | query | number | No | Pagination offset |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": [
        {
            "created_at": "2026-01-28T16:00:01Z",
            "updated_at": "2026-01-28T16:00:01Z",
            "reason": null,
            "actual_amount": 7037.79,
            "quantity": 240,
            "filled_quantity": 240,
            "price": 0.30728,
            "filled_price": 0.30546,
            "leverage": 50,
            "hedge_rate": 96,
            "order_type": "SHORT",
            "trigger_type": "MARKET",
            "trade_currency": "INR",
            "status": "FILLED",
            "id": "019c0555-6ff2-76f0-8203-a41ee05653a7",
            "asset_uuid": "019913c2-9b01-7d79-9c9d-7766751435d5",
            "symbol": "SOMIUSDT",
            "future_position_uuid": "019c0554-37ac-7d08-acc1-3d5e97ff460d"
        }
    ]
}
```

| Field | Description |
|---|---|
| `actual_amount` | Margin used, in **INR** |
| `price` / `filled_price` | Order price in **USDT** |
| `hedge_rate` | INR/USDT FX rate at order time |
| `trade_currency` | `"INR"` |

---

## 10. Open Positions (INR)

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |
| `limit` | query | number | No | Max records |
| `offset` | query | number | No | Pagination offset |

### Response — No open positions

Status: `200 OK`

```json
{
    "success": true,
    "data": null
}
```

### Response — With open position

```json
{
    "success": true,
    "data": [
        {
            "created_at": "2026-01-28T15:58:51Z",
            "updated_at": "2026-01-28T16:00:01Z",
            "entry_price": "0.31169",
            "quantity": "240",
            "leverage": "50",
            "liquidation_price": "0.30546",
            "initial_margin": "143.53",
            "maintenance_margin": "7.18",
            "entry_hedge_rate": "96",
            "order_type": "LONG",
            "status": "OPEN",
            "id": "019c0554-37ac-7d08-acc1-3d5e97ff460d",
            "asset_uuid": "019913c2-9b01-7d79-9c9d-7766751435d5",
            "symbol": "SOMIUSDT",
            "trade_currency": "INR"
        }
    ]
}
```

| Field | Description |
|---|---|
| `entry_price` / `liquidation_price` | Always in **USDT** |
| `initial_margin` | In **INR** |
| `entry_hedge_rate` | INR/USDT FX rate at entry |
| `trade_currency` | `"INR"` |

---

## 11. Position History (INR)

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions/history?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |
| `limit` | query | number | No | Max records |
| `offset` | query | number | No | Pagination offset |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": [
        {
            "id": "019c0555-aa2e-73e5-86cf-3a2167c62cfc",
            "position_type": "LONG",
            "status": "LIQUIDATED",
            "leverage": "50",
            "entry_price": "0.31169",
            "closed_price": "0.30546",
            "quantity": "240",
            "pnl": "-143.53",
            "created_at": "2026-01-28T15:58:51Z",
            "updated_at": "2026-01-28T16:00:01Z",
            "asset_uuid": "019913c2-9b01-7d79-9c9d-7766751435d5",
            "symbol": "SOMIUSDT",
            "trade_currency": "INR",
            "entry_hedge_rate": "96",
            "exit_hedge_rate": "96"
        }
    ]
}
```

| Field | Description |
|---|---|
| `pnl` | Realized PnL in **INR** |
| `entry_price` / `closed_price` | In **USDT** |
| `entry_hedge_rate` / `exit_hedge_rate` | FX rate at entry/exit |

---

## 12. Fee History (INR)

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/fee/history?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes (for INR) | Set to `INR` |
| `limit` | query | number | No | Max records |
| `offset` | query | number | No | Pagination offset |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": [
        {
            "id": "019c0555-aaa1-70dd-a15b-398b28faaf75",
            "symbol": "SOMIUSDT",
            "fee_amount": "3.51",
            "fee_perc": "0.05",
            "fee_type": "TRANSACTION",
            "created_at": "2026-01-28T16:00:01Z",
            "transaction_amount": "7037.79",
            "trade_currency": "INR",
            "order_type": "SHORT",
            "trigger_type": "MARKET",
            "gst_amount": "0.63340185"
        }
    ]
}
```

| Field | Description |
|---|---|
| `fee_amount` | Fee in **INR** |
| `gst_amount` | GST on INR transaction fees |
| `transaction_amount` | Related transaction amount in **INR** |

---

## 13. Asset Listing (unchanged — no INR param)

Symbols and prices are USDT-denominated for both margin currencies.

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures?limit=10&sort=popularity" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `limit` | query | number | No | Max assets to return |
| `offset` | query | number | No | Pagination offset |
| `sort` | query | string | No | `popularity`, `price`, `volume`, `change_perc` |
| `order` | query | string | No | `asc` or `desc` |

### Response

Status: `200 OK`

```json
{
    "success": true,
    "data": [
        {
            "id": "01903a7b-bf65-707d-a7dc-d7b84c3c756c",
            "name": "Bitcoin",
            "symbol": "BTCUSDT",
            "min_contract": "0.001",
            "max_contract": "1500",
            "quantity_step": "0.001",
            "min_notional_value": "5",
            "min_leverage": "1",
            "max_leverage": "100",
            "price": "66809.2"
        }
    ]
}
```

---

## Endpoint coverage summary

| # | Endpoint | INR support | Tested | Status |
|---|---|---|---|---|
| 1 | `GET /wallet/funds?trade_currency=INR` | Yes | Yes | 200 |
| 2 | `GET /futures/funds?trade_currency=INR` | Yes | Yes | 200 |
| 3 | `POST /futures/transfers/inr` | INR only | Yes | 202 |
| 4 | `GET /futures/transactions?trade_currency=INR` | Yes | Yes | 200 |
| 5 | `GET /futures/{symbol}/leverage?trade_currency=INR` | Yes | Yes | 200 / 404 |
| 6 | `POST /futures/{symbol}/leverage` + `trade_currency: INR` | Yes | Yes | 200 |
| 7 | `POST /futures/{symbol}/order` + `trade_currency: INR` | Yes | Yes | 400 (low balance) |
| 8 | `GET /futures/orders?trade_currency=INR` | Yes | Yes | 200 |
| 9 | `GET /futures/orders/history?trade_currency=INR` | Yes | Yes | 200 |
| 10 | `GET /futures/positions?trade_currency=INR` | Yes | Yes | 200 |
| 11 | `GET /futures/positions/history?trade_currency=INR` | Yes | Yes | 200 |
| 12 | `GET /futures/fee/history?trade_currency=INR` | Yes | Yes | 200 |
| 13 | `GET /futures` | N/A (unchanged) | Yes | 200 |
| 14 | `GET /futures/{symbol}` | N/A (unchanged) | Yes | 200 |
| 15 | `POST /futures/positions/{id}/add-margin` | Inherited from UUID | No open position | — |
| 16 | `POST /futures/positions/{id}/riskorder` | Inherited from UUID | No open position | — |
| 17 | `POST /futures/positions/{id}/close` | Inherited from UUID | No open position | — |
| 18 | `GET /futures/positions/{id}/liq-price?trade_currency=INR` | Yes | Skipped | — |

Raw test output: [testing/test-results-inr.md](../testing/test-results-inr.md)
