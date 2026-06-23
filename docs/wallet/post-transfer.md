# Transfer funds — INR

Move INR between your INR spot wallet and INR futures wallet.

> INR transfers use `POST /futures/transfers/inr`. Do **not** use `/wallet/futures/transfer` for INR.

## cURL — Spot to Futures

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

## cURL — Futures to Spot

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

## Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `amount` | body | string | Yes | INR amount to transfer (positive decimal) |
| `from_wallet_type` | body | string | Yes | `"SPOT"` or `"FUTURES"` |
| `to_wallet_type` | body | string | Yes | Must be opposite of `from_wallet_type` |

## Response — Success

Status: `202 Accepted`

```json
{
    "success": true,
    "data": {
        "id": "019ecc4e-6f26-77ee-98dd-deb23ca6af32"
    }
}
```

## Response — Insufficient balance

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

## Live test result — 89.12 INR transfer

| Step | INR Spot | INR Futures |
|---|---|---|
| Before transfer | `0` (API) | `25.8129` |
| Transfer `89.12` SPOT → FUTURES | — | — |
| After transfer (Completed) | `0` | `114.9329` |

```bash
curl -X POST "https://trade.mudrex.com/fapi/v1/futures/transfers/inr" \
  -H "Content-Type: application/json" \
  -H "X-Authentication: your-secret-key" \
  -d '{"amount": "89.12", "from_wallet_type": "SPOT", "to_wallet_type": "FUTURES"}'
```

```json
{
    "success": true,
    "data": {
        "id": "019ecc51-9004-7dd1-8654-64420289af4e"
    }
}
```

> `GET /wallet/funds?trade_currency=INR` showed `0` even though `89.12` was transferable. Use the known amount in the transfer request.
