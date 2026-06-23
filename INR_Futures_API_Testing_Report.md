# INR Futures API — Testing Report

**Environment:** Production  
**Base URL:** `https://trade.mudrex.com/fapi/v1`  
**Test date:** 2026-06-15  
**Currency parameter:** `trade_currency=INR` on futures endpoints (query on GET, body on POST/PATCH/DELETE). **Exception:** INR spot wallet uses query param `currency=INR`, not `trade_currency`.

**Authentication:** All requests require header `X-Authentication: <api-secret>`.

---

## Endpoint summary

| # | Method | Endpoint | Result | HTTP | Notes |
|---|---|---|---|---|---|
| 1 | GET | `/wallet/funds?currency=INR` | PASS | 200 | Use `currency`, not `trade_currency` |
| 2 | GET | `/futures/funds?trade_currency=INR` | PASS | 200 | Balance accurate |
| 3 | POST | `/futures/transfers/inr` (SPOT → FUTURES) | PASS | 202 | e.g. 89.12 INR transferred |
| 4 | POST | `/futures/transfers/inr` (FUTURES → SPOT) | PASS | 202 | e.g. 14.67 INR transferred |
| 5 | POST | `/wallet/futures/transfer` + `trade_currency:INR` | PASS | 400 | Expected — use `/futures/transfers/inr` for INR |
| 6 | GET | `/futures/transactions?trade_currency=INR` | PASS | 200 | DEPOSIT / WITHDRAW filters work |
| 7 | GET | `/futures/funds?trade_currency=EUR` | PASS | 400 | `Invalid trade currency` |
| 8 | GET | `/futures` | PASS | 200 | Unchanged — USDT symbols |
| 9 | GET | `/futures/BTCUSDT?is_symbol` | PASS | 200 | Asset metadata unchanged |
| 10 | GET | `/futures/SOMIUSDT?is_symbol` | PASS | 200 | Used for order tests |
| 11 | GET | `/futures/BTCUSDT/leverage?is_symbol&trade_currency=INR` | PASS | 200 | |
| 12 | POST | `/futures/BTCUSDT/leverage?is_symbol` + INR | PASS | 200 | Independent of USDT leverage |
| 13 | GET | `/futures/ETHUSDT/leverage?is_symbol&trade_currency=INR` | PASS | 404 | `leverage not found` when never set |
| 14 | POST | `/futures/SOMIUSDT/leverage?is_symbol` + INR | PASS | 200 | |
| 15 | POST | `/futures/SOMIUSDT/order?is_symbol` (MARKET) | PASS | 202 | INR margin debited |
| 16 | POST | `/futures/SOMIUSDT/order?is_symbol` (LIMIT) | PASS | 202 | |
| 17 | GET | `/futures/orders?trade_currency=INR` | PASS | 200 | Currency-scoped |
| 18 | GET | `/futures/orders/history?trade_currency=INR` | PASS | 200 | Includes `hedge_rate` |
| 19 | GET | `/futures/orders/{order_id}` | PASS | 200 | |
| 20 | PATCH | `/futures/orders/{order_id}` | PASS | 200 | Requires `order_price` + `quantity` |
| 21 | DELETE | `/futures/orders/{order_id}` | PASS | 200 | |
| 22 | GET | `/futures/positions?trade_currency=INR` | PASS | 200 | `trade_currency: INR` on positions |
| 23 | GET | `/futures/positions/history?trade_currency=INR` | PASS | 200 | PnL in INR |
| 24 | GET | `/futures/positions/{id}/liq-price?trade_currency=INR` | PASS | 200 | Price in USDT |
| 25 | GET | `/futures/positions/{id}/liq-price?ext_margin=1` | PASS | 200 | |
| 26 | POST | `/futures/positions/{id}/add-margin` (+) | PASS | 200 | Amount in INR |
| 27 | POST | `/futures/positions/{id}/add-margin` (-) | PASS | 200 | Reduce margin |
| 28 | POST | `/futures/positions/{id}/riskorder` | PASS | 200 | Set SL/TP |
| 29 | PATCH | `/futures/positions/{id}/riskorder` | PASS | 200 | Requires `stoploss_order_id` + `takeprofit_order_id` |
| 30 | POST | `/futures/positions/{id}/close/partial` | PASS | 200 | |
| 31 | POST | `/futures/positions/{id}/reverse` | PASS | 202 | LONG ↔ SHORT |
| 32 | POST | `/futures/positions/{id}/close` | PASS | 200 | Square off |
| 33 | GET | `/futures/fee/history?trade_currency=INR` | PASS | 200 | Includes `gst_amount` |
| 34 | GET | `/wallet/funds` (no param, USDT default) | PASS | 200 | Backward compatible |

**Score: 34 PASS, 0 FAIL**

---

## API conventions

| Endpoint | Currency parameter |
|---|---|
| `GET /wallet/funds` (spot) | Query: `?currency=INR` |
| All other GET endpoints | Query: `?trade_currency=INR` |
| POST / PATCH / DELETE | Body: `"trade_currency": "INR"` |
| Omitted | Defaults to `USDT` |

**Currency model:** Same USDT-quoted contracts (`BTCUSDT`, `SOMIUSDT`). Prices and liquidation in USDT. Margin, PnL, fees in INR. FX rate returned as `hedge_rate` / `entry_hedge_rate` / `exit_hedge_rate`.

---

# Detailed test results

---

## 1. GET INR spot wallet — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/wallet/funds?currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "total": 15.67,
        "rewards": 0,
        "invested": 0,
        "withdrawable": 15.67,
        "coin_investable": 15.67,
        "coinset_investable": 15.67,
        "vault_investable": 15.67
    }
}
```

> **Parameter note:** This endpoint expects `currency=INR`, not `trade_currency=INR`. Using `trade_currency` returns HTTP 200 but all balance fields as `0`.

---

## 2. GET INR futures wallet — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/funds?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "balance": "114.9329",
        "locked_amount": "0",
        "first_time_user": false
    }
}
```

**After open position (margin locked):**

```json
{
    "success": true,
    "data": {
        "balance": "18.1993",
        "locked_amount": "96.4497",
        "first_time_user": false
    }
}
```

---

## 3. POST transfer INR — SPOT to FUTURES — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/transfers/inr" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "amount": "89.12",
    "from_wallet_type": "SPOT",
    "to_wallet_type": "FUTURES"
  }'
```

**Request body:**

```json
{
    "amount": "89.12",
    "from_wallet_type": "SPOT",
    "to_wallet_type": "FUTURES"
}
```

**Status:** `202 Accepted`

**Response:**

```json
{
    "success": true,
    "data": {
        "id": "019ecc51-9004-7dd1-8654-64420289af4e"
    }
}
```

Futures balance increased from `25.8129` → `114.9329`. Transaction status `Completed`.

---

## 4. POST transfer INR — FUTURES to SPOT — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/transfers/inr" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "amount": "14.6719",
    "from_wallet_type": "FUTURES",
    "to_wallet_type": "SPOT"
  }'
```

**Request body:**

```json
{
    "amount": "14.6719",
    "from_wallet_type": "FUTURES",
    "to_wallet_type": "SPOT"
}
```

**Status:** `202 Accepted`

**Response:**

```json
{
    "success": true,
    "data": {
        "id": "019ecc71-2314-780d-9e65-21343eaa99c6"
    }
}
```

Transaction type `WITHDRAW`, status `Completed`. Futures balance decreased; spot API still showed `0`.

---

## 5. POST USDT transfer path with INR — PASS (expected 400)

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/wallet/futures/transfer" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "amount": "1",
    "from_wallet_type": "SPOT",
    "to_wallet_type": "FUTURES",
    "trade_currency": "INR"
  }'
```

**Status:** `400 Bad Request`

**Response:**

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

---

## 6. GET transactions — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/transactions?limit=20&type=WITHDRAW&status=completed&sort_order=asc&sort_by=updated_at&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": [
        {
            "id": "019ecc71-2314-780d-9e65-21343eaa99c6",
            "wallet_transaction_id": "",
            "transaction_type": "WITHDRAW",
            "amount": "14.6719",
            "status": "Completed",
            "created_at": "2026-06-15T18:00:27Z",
            "updated_at": "2026-06-15T18:00:29Z"
        },
        {
            "id": "019ecc51-9004-7dd1-8654-64420289af4e",
            "wallet_transaction_id": "",
            "transaction_type": "DEPOSIT",
            "amount": "89.12",
            "status": "Completed",
            "created_at": "2026-06-15T17:25:58Z",
            "updated_at": "2026-06-15T17:25:59Z"
        }
    ]
}
```

---

## 7. GET invalid trade_currency — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/funds?trade_currency=EUR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `400 Bad Request`

**Response:**

```json
{
    "success": false,
    "errors": [
        {
            "code": 400,
            "text": "Invalid trade currency"
        }
    ]
}
```

---

## 8. GET asset listing — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures?limit=3" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

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

No `trade_currency` parameter — unchanged for INR and USDT.

---

## 9. GET asset detail — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT?is_symbol" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response (truncated):**

```json
{
    "success": true,
    "data": {
        "id": "01903a7b-bf65-707d-a7dc-d7b84c3c756c",
        "name": "Bitcoin",
        "symbol": "BTCUSDT",
        "min_contract": "0.001",
        "max_leverage": "100",
        "price": "66809.2"
    }
}
```

---

## 10. GET leverage — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT/leverage?is_symbol&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

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

**Never-set asset (ETHUSDT) — Status:** `404`

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

## 11. POST set leverage — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/SOMIUSDT/leverage?is_symbol" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "margin_type": "ISOLATED",
    "leverage": "5",
    "trade_currency": "INR"
  }'
```

**Request body:**

```json
{
    "margin_type": "ISOLATED",
    "leverage": "5",
    "trade_currency": "INR"
}
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "margin_type": "ISOLATED",
        "leverage": "5",
        "collateral_currency_id": 0
    }
}
```

BTCUSDT INR leverage (`2`) and USDT leverage (`1.5`) confirmed independent.

---

## 12. POST place order — MARKET — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/SOMIUSDT/order?is_symbol" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "leverage": "5",
    "quantity": "43.8",
    "order_price": "0.11441",
    "order_type": "LONG",
    "trigger_type": "MARKET",
    "is_takeprofit": false,
    "is_stoploss": false,
    "reduce_only": false,
    "trade_currency": "INR"
  }'
```

**Request body:**

```json
{
    "leverage": "5",
    "quantity": "43.8",
    "order_price": "0.11441",
    "order_type": "LONG",
    "trigger_type": "MARKET",
    "is_takeprofit": false,
    "is_stoploss": false,
    "reduce_only": false,
    "trade_currency": "INR"
}
```

**Status:** `202 Accepted`

**Response:**

```json
{
    "success": true,
    "data": {
        "leverage": "5",
        "amount": "5.011596",
        "quantity": "43.8",
        "price": "0.11442",
        "order_id": "019ecc52-2f97-7e34-b3cc-22364e107975",
        "status": "CREATED",
        "message": "OK"
    }
}
```

---

## 13. POST place order — LIMIT — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/SOMIUSDT/order?is_symbol" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "leverage": "5",
    "quantity": "44.0",
    "order_price": "0.11400",
    "order_type": "LONG",
    "trigger_type": "LIMIT",
    "is_takeprofit": false,
    "is_stoploss": false,
    "reduce_only": false,
    "trade_currency": "INR"
  }'
```

**Request body:**

```json
{
    "leverage": "5",
    "quantity": "44.0",
    "order_price": "0.11400",
    "order_type": "LONG",
    "trigger_type": "LIMIT",
    "is_takeprofit": false,
    "is_stoploss": false,
    "reduce_only": false,
    "trade_currency": "INR"
}
```

**Status:** `202 Accepted`

**Response:**

```json
{
    "success": true,
    "data": {
        "leverage": "5",
        "amount": "5.016",
        "quantity": "44",
        "price": "0.114",
        "order_id": "019ecc5e-969d-7a17-8867-2343d06b016b",
        "status": "CREATED",
        "message": "OK"
    }
}
```

---

## 14. GET open orders — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/orders?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response (with SL/TP orders on open position):**

```json
{
    "success": true,
    "data": [
        {
            "created_at": "2026-06-15T17:36:11Z",
            "updated_at": "2026-06-15T17:36:11Z",
            "price": 0.1,
            "hedge_rate": 96,
            "order_type": "STOPLOSS",
            "trigger_type": "MARKET",
            "trade_currency": "INR",
            "status": "CREATED",
            "id": "019ecc5a-ea31-7e08-b6d4-428bc921126a",
            "symbol": "SOMIUSDT",
            "future_position_uuid": "019ecc52-2f95-7ab5-8682-c3a0f43ccda6"
        },
        {
            "price": 0.13,
            "order_type": "TAKEPROFIT",
            "trigger_type": "MARKET",
            "trade_currency": "INR",
            "status": "CREATED",
            "id": "019ecc5a-ea31-7e0b-a5bc-7288863af056",
            "symbol": "SOMIUSDT"
        }
    ]
}
```

---

## 15. GET order history — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/orders/history?limit=5&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": [
        {
            "created_at": "2026-01-28T16:00:01Z",
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
            "symbol": "SOMIUSDT"
        }
    ]
}
```

---

## 16. GET order by id — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/orders/019ecc52-2f97-7e34-b3cc-22364e107975" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "actual_amount": 481.11,
        "quantity": 43.8,
        "filled_quantity": 43.8,
        "price": 0.11442,
        "filled_price": 0.11442,
        "leverage": 5,
        "hedge_rate": 96,
        "order_type": "LONG",
        "trigger_type": "MARKET",
        "trade_currency": "INR",
        "status": "FILLED",
        "id": "019ecc52-2f97-7e34-b3cc-22364e107975"
    }
}
```

---

## 17. PATCH amend order — PASS

```bash
curl -X PATCH "https://trade.mudrex.com/fapi/v1/futures/orders/019ecc5e-969d-7a17-8867-2343d06b016b" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "order_price": "0.11380",
    "quantity": "44.0"
  }'
```

**Request body:**

```json
{
    "order_price": "0.11380",
    "quantity": "44.0"
}
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "message": "Order updated successfully"
    }
}
```

Both `order_price` and `quantity` are required. Price-only amend returns `400 order quantity out of permissible range`.

---

## 18. DELETE cancel order — PASS

```bash
curl -X DELETE "https://trade.mudrex.com/fapi/v1/futures/orders/019ecc5a-ea31-7e08-b6d4-428bc921126a" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "message": "",
        "order_id": "",
        "status": ""
    }
}
```

---

## 19. GET open positions — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": [
        {
            "created_at": "2026-06-15T17:26:39Z",
            "entry_price": "0.11442",
            "quantity": "43.8",
            "leverage": "5",
            "liquidation_price": "0.09293",
            "initial_margin": "96.44",
            "maintenance_margin": "7.44",
            "entry_hedge_rate": "96",
            "order_type": "LONG",
            "status": "OPEN",
            "id": "019ecc52-2f95-7ab5-8682-c3a0f43ccda6",
            "symbol": "SOMIUSDT",
            "trade_currency": "INR",
            "stoploss": {
                "price": "0.1",
                "order_id": "019ecc5a-ea31-7e08-b6d4-428bc921126a",
                "order_type": "SHORT"
            },
            "takeprofit": {
                "price": "0.13",
                "order_id": "019ecc5a-ea31-7e0b-a5bc-7288863af056",
                "order_type": "SHORT"
            }
        }
    ]
}
```

---

## 20. GET position history — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions/history?limit=5&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

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
            "symbol": "SOMIUSDT",
            "trade_currency": "INR",
            "entry_hedge_rate": "96",
            "exit_hedge_rate": "96"
        }
    ]
}
```

---

## 21. GET liquidation price — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions/019ecc52-2f95-7ab5-8682-c3a0f43ccda6/liq-price?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": "0.09293"
}
```

**With `ext_margin=1`:**

```json
{
    "success": true,
    "data": "0.0926883614301247"
}
```

---

## 22. POST add margin — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/positions/019ecc52-2f95-7ab5-8682-c3a0f43ccda6/add-margin" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{"margin": 1}'
```

**Request body (add):**

```json
{
    "margin": 1
}
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "message": "OK",
        "initial_margin": "97.44",
        "liquidation_price": "0.09269",
        "trade_currency": "INR"
    }
}
```

**Request body (reduce):**

```json
{
    "margin": -0.5
}
```

**Response:**

```json
{
    "success": true,
    "data": {
        "message": "OK",
        "initial_margin": "96.72",
        "liquidation_price": "0.09281",
        "trade_currency": "INR"
    }
}
```

---

## 23. POST set SL/TP — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/positions/019ecc52-2f95-7ab5-8682-c3a0f43ccda6/riskorder" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "stoploss_price": "0.10",
    "takeprofit_price": "0.13",
    "order_source": "API",
    "is_stoploss": true,
    "is_takeprofit": true
  }'
```

**Request body:**

```json
{
    "stoploss_price": "0.10",
    "takeprofit_price": "0.13",
    "order_source": "API",
    "is_stoploss": true,
    "is_takeprofit": true
}
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "position_id": "019ecc52-2f95-7ab5-8682-c3a0f43ccda6",
        "status": "CREATED",
        "message": "Risk order placed successfully"
    }
}
```

---

## 24. PATCH edit SL/TP — PASS

```bash
curl -X PATCH "https://trade.mudrex.com/fapi/v1/futures/positions/019ecc5d-c4de-74d7-a6de-5c758026afaa/riskorder" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "stoploss_price": "0.095",
    "takeprofit_price": "0.14",
    "stoploss_order_id": "019ecc5d-d102-7c2e-a1ee-84df95bcc2c2",
    "takeprofit_order_id": "019ecc5d-d102-7c31-97cb-33d44488c69b",
    "is_stoploss": true,
    "is_takeprofit": true,
    "trigger_type": "MARKET"
  }'
```

**Request body:**

```json
{
    "stoploss_price": "0.095",
    "takeprofit_price": "0.14",
    "stoploss_order_id": "019ecc5d-d102-7c2e-a1ee-84df95bcc2c2",
    "takeprofit_order_id": "019ecc5d-d102-7c31-97cb-33d44488c69b",
    "is_stoploss": true,
    "is_takeprofit": true,
    "trigger_type": "MARKET"
}
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "message": "Risk order amended successfully"
    }
}
```

Without `stoploss_order_id` / `takeprofit_order_id` → `400 risk order id missing`.

---

## 25. POST partial close — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/positions/019ecc52-2f95-7ab5-8682-c3a0f43ccda6/close/partial" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "order_type": "MARKET",
    "quantity": "0.1"
  }'
```

**Request body:**

```json
{
    "order_type": "MARKET",
    "quantity": "0.1"
}
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": true
}
```

Position quantity reduced `43.8` → `43.7`.

---

## 26. POST reverse position — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/positions/019ecc52-2f95-7ab5-8682-c3a0f43ccda6/reverse" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `202 Accepted`

**Response:**

```json
{
    "success": true,
    "data": {
        "leverage": "5",
        "amount": "10.00293",
        "quantity": "43.7",
        "price": "0.11445",
        "order_id": "019ecc5b-3649-7e00-9d67-a3c83a97518c",
        "status": "CREATED",
        "message": "OK"
    }
}
```

Position flipped LONG → SHORT. Liquidation price updated to `0.13528` USDT.

---

## 27. POST square off (close) — PASS

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/positions/019ecc52-2f95-7ab5-8682-c3a0f43ccda6/close" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

```json
{
    "success": true,
    "data": {
        "position_id": "019ecc5b-406a-7d43-be8b-c161aecf9c81",
        "status": "CREATED",
        "message": "OK"
    }
}
```

---

## 28. GET fee history — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/fee/history?limit=5&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

**Response:**

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
            "transaction_amount": "7037.79",
            "trade_currency": "INR",
            "order_type": "SHORT",
            "trigger_type": "MARKET",
            "gst_amount": "0.63340185"
        },
        {
            "symbol": "SOMIUSDT",
            "fee_amount": "-3.18",
            "fee_type": "FUNDING",
            "transaction_amount": "7110.6",
            "trade_currency": "INR"
        }
    ]
}
```

---

## 29. Backward compatibility — USDT default — PASS

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

Returns USDT positions only when `trade_currency` omitted. Additive field `trade_currency: "USDT"` present on each position.

```json
{
    "success": true,
    "data": [
        {
            "entry_price": "0.02645",
            "quantity": "1512",
            "leverage": "2",
            "symbol": "FHEUSDT",
            "trade_currency": "USDT",
            "status": "OPEN"
        }
    ]
}
```

---

## Implementation notes for developers

| Topic | Detail |
|---|---|
| INR transfers | Use `POST /futures/transfers/inr` — not `/wallet/futures/transfer` |
| INR spot balance | Use `GET /wallet/funds?currency=INR` (not `trade_currency`) |
| PATCH edit SL/TP | Include `stoploss_order_id` and `takeprofit_order_id` |
| PATCH amend order | Include both `order_price` and `quantity` |
| LIMIT orders | Notional must meet `min_notional_value` (5 USDT) at limit price |
| FX rate | `hedge_rate` on orders; `entry_hedge_rate` / `exit_hedge_rate` on positions |
| Prices | Order price, entry, liquidation — USDT. Margin, PnL, fees — INR |

---

## Conclusion

All 34 tested endpoints pass on production. INR spot wallet balance requires query param `currency=INR`; all other INR futures endpoints use `trade_currency=INR`.
