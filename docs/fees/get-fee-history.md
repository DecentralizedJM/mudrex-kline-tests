# Fee history — INR

Retrieve trading and funding fees charged in INR.

## cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/futures/fee/history?limit=20&trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

## Parameters

| Name | In | Type | Required | Description |
|---|---|---|---|---|
| `trade_currency` | query | string | Yes | Set to `INR` |
| `limit` | query | number | No | Max records (default: 10) |
| `offset` | query | number | No | Pagination offset |

## Response

Status: `200 OK`

```json
{
    "success": true,
    "data": [
        {
            "id": "019c0555-aaa1-70dd-a15b-398b28faaf75",
            "symbol": "SOMIUSDT",
            "fee_amount": "3.51",
            "fee_perc": "0.05",
            "fee_type": "TRANSACTION",
            "created_at": "2026-01-28T16:00:01Z",
            "transaction_amount": "7037.79",
            "trade_currency": "INR",
            "order_type": "SHORT",
            "trigger_type": "MARKET",
            "gst_amount": "0.63340185"
        },
        {
            "id": "019c0555-62c7-7a98-8161-0bdad802efb7",
            "symbol": "SOMIUSDT",
            "fee_amount": "-3.18",
            "fee_perc": "-0.044743",
            "fee_type": "FUNDING",
            "created_at": "2026-01-28T16:00:00Z",
            "transaction_amount": "7110.6",
            "trade_currency": "INR"
        }
    ]
}
```

## Response fields

| Field | Description |
|---|---|
| `fee_amount` | Fee in INR (negative for rebates/funding credits) |
| `transaction_amount` | Related transaction amount in INR |
| `trade_currency` | `"INR"` |
| `fee_type` | `TRANSACTION` or `FUNDING` |
| `gst_amount` | GST on INR transaction fees |
| `order_type` | `LONG` or `SHORT` (transaction fees only) |
| `trigger_type` | `MARKET` or `LIMIT` (transaction fees only) |
