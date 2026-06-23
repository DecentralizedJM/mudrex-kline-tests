# Quickstart (INR)

End-to-end INR-margined futures trading via API. All cURL examples tested on production.

## Step 1 — Check INR balances

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/wallet/funds?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/funds?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Response (futures wallet)

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

## Step 2 — Transfer INR spot → futures

Only needed if INR is in your spot wallet. Use when `withdrawable > 0` on spot.

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

| Field | Value |
|---|---|
| `amount` | INR amount to move |
| `from_wallet_type` | `"SPOT"` |
| `to_wallet_type` | `"FUTURES"` |

### Response

```json
{
    "success": true,
    "data": {
        "id": "019ecc4e-6f26-77ee-98dd-deb23ca6af32"
    }
}
```

## Step 3 — Set leverage (INR)

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

| Field | Value |
|---|---|
| `margin_type` | `"ISOLATED"` |
| `leverage` | Within asset min/max |
| `trade_currency` | `"INR"` |

### Response

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

## Step 4 — Place order (INR margin)

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

| Field | Value | Note |
|---|---|---|
| `trade_currency` | `"INR"` | Margin from INR wallet |
| `order_price` | USDT price | Not converted |
| `quantity` | Base asset | e.g. BTC amount |
| `leverage` | e.g. `"2"` | Must be set for INR first |

### Response (success)

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

## Step 5 — Monitor

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/transactions?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

See the full reference: [INR Margin API Reference](inr-margin-api-reference.md)
