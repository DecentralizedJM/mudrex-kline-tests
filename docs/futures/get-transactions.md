# Get transactions — INR

Retrieve INR futures wallet transaction history.

## cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/transactions?limit=20&type=WITHDRAW&status=completed&sort_order=asc&sort_by=updated_at&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

## Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes | Set to `INR` |
| `limit` | query | number | No | Max records (default: 20) |
| `type` | query | string | No | Filter: `DEPOSIT` or `WITHDRAW` |
| `status` | query | string | No | Filter: `completed`, `Processing`, etc. |
| `sort_order` | query | string | No | `asc` or `desc` |
| `sort_by` | query | string | No | Sort field, e.g. `updated_at` |

## Response

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

## Response fields

| Field | Description |
|---|---|
| `id` | Transaction UUID |
| `transaction_type` | `DEPOSIT` (spot→futures) or `WITHDRAW` (futures→spot) |
| `amount` | Amount in INR |
| `status` | `Completed` or `Processing` |
| `wallet_transaction_id` | Linked wallet transaction (may be empty) |

## Filter examples

**DEPOSIT only:**

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/transactions?limit=5&type=DEPOSIT&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**WITHDRAW only:**

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/transactions?limit=5&type=WITHDRAW&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```
