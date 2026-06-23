# Errors (INR)

Error responses follow the existing Mudrex API format. INR-specific errors use the same structure.

## Standard error response

```json
{
    "success": false,
    "errors": [
        {
            "code": 400,
            "text": "Error message"
        }
    ]
}
```

## INR-specific errors (observed)

| Status | Error text | When |
|---|---|---|
| `400` | `Invalid trade currency` | `trade_currency` is not `USDT` or `INR` |
| `400` | `insufficient balance` | INR wallet has insufficient funds for transfer or order |
| `400` | `From and To wallet types must be different` | Transfer with same source and destination wallet |

### Invalid trade currency

Triggered when passing an unsupported value (e.g., `EUR`):

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/funds?trade_currency=EUR" \
  -H "X-Authentication: your-secret-key"
```

Response:

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

### Insufficient INR balance (transfer via wrong endpoint)

Attempting INR transfer through the USDT endpoint:

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/wallet/futures/transfer" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{
    "from_wallet_type": "SPOT",
    "to_wallet_type": "FUTURES",
    "amount": "1",
    "trade_currency": "INR"
  }'
```

Response:

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

Status: `400 Bad Request`

> Use `POST /futures/transfers/inr` for INR transfers instead.

### Insufficient INR balance (order)

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

Status: `400 Bad Request`

## Existing errors (unchanged)

These errors apply equally to USDT and INR operations:

| Status | Error text | Description |
|---|---|---|
| `400` | `Params error` | Bad or missing parameter |
| `400` | `invalid trigger type` | Invalid `trigger_type` value |
| `400` | `invalid order type` | Invalid `order_type` value |
| `400` | `order price out of permissible range` | Price outside asset limits |
| `400` | `quantity not a multiple of the quantity step` | Invalid quantity step |
| `400` | `leverage out of permissible range` | Leverage outside asset limits |
| `401` | — | Invalid or missing `X-Authentication` |
| `404` | — | Resource not found |
| `429` | — | Rate limit exceeded |

## Open items for engineering

- Confirm whether `Invalid trade currency` should name supported values (`USDT`, `INR`) in the error text per PRD §8
- Document any additional INR-specific error codes as they are defined
