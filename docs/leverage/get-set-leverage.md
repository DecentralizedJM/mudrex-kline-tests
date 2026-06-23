# Leverage — INR

Get or set leverage for a futures asset using INR margin. Leverage is independent per (asset, currency).

## Get leverage — cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/BTCUSDT/leverage?is_symbol&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

## Set leverage — cURL

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

## Parameters — GET

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `asset_id` | path | string | Yes | Symbol (e.g. `BTCUSDT`) with `is_symbol` |
| `is_symbol` | query | flag | Yes | Treat path as trading symbol |
| `trade_currency` | query | string | Yes | Set to `INR` |

## Parameters — POST

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `asset_id` | path | string | Yes | Symbol (e.g. `BTCUSDT`) with `is_symbol` |
| `is_symbol` | query | flag | Yes | Treat path as trading symbol |
| `margin_type` | body | string | Yes | `"ISOLATED"` |
| `leverage` | body | string | Yes | Within asset min/max range |
| `trade_currency` | body | string | Yes | Set to `INR` |

## Response — GET (set previously)

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

## Response — GET (never set)

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

## Response — POST (set)

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

## Live test

| Asset | Currency | Leverage after set |
|---|---|---|
| BTCUSDT | INR | `2` |
| BTCUSDT | USDT | `1.5` (independent) |
| ETHUSDT | INR | 404 — never set |
