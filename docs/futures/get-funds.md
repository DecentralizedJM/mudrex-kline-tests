# Funds (futures) — INR

Fetch your INR futures wallet balance and locked margin.

## cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/funds?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

## Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes | Set to `INR` |

## Response

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

## Response fields

| Field | Description |
|---|---|
| `balance` | Available INR in futures wallet for trading |
| `locked_amount` | INR locked as open-position margin |
| `first_time_user` | `true` if you have never used INR futures |

## Common errors

### Invalid trade currency

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/funds?trade_currency=EUR" \
  -H "X-Authentication: your-secret-key"
```

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

Status: `400 Bad Request`
