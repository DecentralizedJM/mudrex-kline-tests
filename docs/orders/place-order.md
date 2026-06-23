# Create new order — INR margin

Place a futures order with margin debited from your INR futures wallet. Prices remain USDT-denominated; quantity is in the base asset.

## cURL

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

## Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `asset_id` | path | string | Yes | Trading symbol (e.g. `BTCUSDT`) |
| `is_symbol` | query | flag | Yes | Treat path as symbol |
| `trade_currency` | body | string | Yes | Set to `INR` |
| `leverage` | body | string | Yes | Leverage (must be set for INR on this asset first) |
| `quantity` | body | string | Yes | Quantity in base asset |
| `order_price` | body | string | Yes | Price in USDT |
| `order_type` | body | string | Yes | `LONG` or `SHORT` |
| `trigger_type` | body | string | Yes | `MARKET` or `LIMIT` |
| `is_takeprofit` | body | boolean | No | Default `false` |
| `is_stoploss` | body | boolean | No | Default `false` |
| `stoploss_price` | body | string | Conditional | USDT; required if `is_stoploss: true` |
| `takeprofit_price` | body | string | Conditional | USDT; required if `is_takeprofit: true` |
| `reduce_only` | body | boolean | No | Default `false` |

## Response — Success (live test: SOMIUSDT)

Status: `202 Accepted`

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

Tested with `114.93` INR in futures wallet after transferring `89.12` from spot.

## Response — Insufficient balance

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

## Response — Below minimum order value

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

## Notes

- `amount` in the success response is margin debited in **INR**.
- `price` is always in **USDT**.
- With ~25 INR futures balance, most orders will fail due to insufficient margin or minimum notional requirements.
