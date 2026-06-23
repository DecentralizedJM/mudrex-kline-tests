# List positions — INR

View open INR positions and INR position history.

## Open positions — cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

## Position history — cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/positions/history?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

## Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes | Set to `INR` |
| `limit` | query | number | No | Max records (default: 20) |
| `offset` | query | number | No | Pagination offset |

## Response — Open positions (live test)

Status: `200 OK`

```json
{
    "success": true,
    "data": [
        {
            "created_at": "2026-06-15T17:26:39Z",
            "updated_at": "2026-06-15T17:26:39Z",
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
            "asset_uuid": "019913c2-9b01-7d79-9c9d-7766751435d5",
            "symbol": "SOMIUSDT",
            "trade_currency": "INR"
        }
    ]
}
```

## Response — Position history

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
        },
        {
            "id": "019c0554-14a7-7d43-8ca9-017c6762c356",
            "position_type": "LONG",
            "status": "CLOSED",
            "leverage": "50",
            "entry_price": "0.3109",
            "closed_price": "0.3115489391304348",
            "quantity": "230",
            "pnl": "14.32",
            "created_at": "2026-01-28T15:57:59Z",
            "updated_at": "2026-01-28T15:58:42Z",
            "asset_uuid": "019913c2-9b01-7d79-9c9d-7766751435d5",
            "symbol": "SOMIUSDT",
            "trade_currency": "INR",
            "entry_hedge_rate": "96",
            "exit_hedge_rate": "96"
        }
    ]
}
```

## Response fields

| Field | Description |
|---|---|
| `trade_currency` | `"INR"` |
| `entry_price` / `closed_price` | USDT |
| `pnl` | Realized PnL in INR |
| `entry_hedge_rate` / `exit_hedge_rate` | INR/USDT FX rate |
| `quantity` | Base asset units |

## Notes

- No open INR positions at time of test — `data: null`.
- Position management (close, add-margin, SL/TP) uses the position UUID and inherits INR currency automatically.
