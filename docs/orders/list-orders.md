# List orders — INR

View open INR orders and INR order history. One currency per call.

## Open orders — cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/orders?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

## Order history — cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/orders/history?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

## Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes | Set to `INR` |
| `limit` | query | number | No | Max records (default: 20) |
| `offset` | query | number | No | Pagination offset |

## Response — Open orders (none)

Status: `200 OK`

```json
{
    "success": true,
    "data": []
}
```

## Response — Order history

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

## Response fields

| Field | Description |
|---|---|
| `trade_currency` | Always `"INR"` in these responses |
| `actual_amount` | Margin in INR |
| `price` / `filled_price` | Order price in USDT |
| `hedge_rate` | INR/USDT FX rate locked at order time |
| `symbol` | USDT-quoted symbol (e.g. `SOMIUSDT`) |
