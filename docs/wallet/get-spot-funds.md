# Funds (spot) — INR

Retrieve your INR spot wallet balance.

## cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/wallet/funds?trade_currency=INR" \
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
        "total": 0,
        "rewards": 0,
        "invested": 0,
        "withdrawable": 0,
        "coin_investable": 0,
        "coinset_investable": 0,
        "vault_investable": 0
    }
}
```

## Response fields

| Field | Description |
|---|---|
| `total` | Total INR spot balance |
| `withdrawable` | INR available for transfer to futures wallet |
| `invested` | Amount currently invested |
| `rewards` | Rewards balance |

## Known issue (tested 2026-06-15)

**This endpoint may not return the actual INR spot balance.**

Observed on production:

- Returns `200 OK` with all fields `0` even when `89.12` INR was successfully transferred from spot → futures
- Still returns all `0` after transferring `14.67` INR back futures → spot (transfer completed, futures balance updated)

Do not use this endpoint to determine how much INR is in your spot wallet. Use `GET /futures/transactions?trade_currency=INR` to audit transfers, or transfer with an explicit `amount` via `POST /futures/transfers/inr`.

`GET /futures/funds?trade_currency=INR` works correctly for the futures wallet.

## Notes

- All values are denominated in INR when the endpoint works correctly.
- Zero balance is valid for users who have never deposited INR — but zero is also returned incorrectly when funds exist.
