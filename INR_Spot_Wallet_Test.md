# GET INR Spot Wallet — Test

**Environment:** Production  
**Base URL:** `https://trade.mudrex.com/fapi/v1`  
**Test date:** 2026-06-15  
**Endpoint:** `GET /wallet/funds`  
**Result:** PASS

---

## Summary

| Method | Endpoint | Result | HTTP |
|---|---|---|---|
| GET | `/wallet/funds?currency=INR` | **PASS** | 200 |
| GET | `/wallet/funds?trade_currency=INR` | Incorrect param | 200 (returns all `0`) |

The INR spot wallet endpoint uses query parameter **`currency`**, not **`trade_currency`**. All other INR futures endpoints use `trade_currency=INR`.

---

## Correct test — PASS

### cURL

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/wallet/funds?currency=INR" \
  -H "X-Authentication: your-secret-key"
```

### Parameters

| Name | In | Type | Required | Value |
|---|---|---|---|---|
| `currency` | query | string | Yes | `INR` |

### Response

**Status:** `200 OK`

```json
{
    "success": true,
    "data": {
        "total": 15.67,
        "rewards": 0,
        "invested": 0,
        "withdrawable": 15.67,
        "coin_investable": 15.67,
        "coinset_investable": 15.67,
        "vault_investable": 15.67
    }
}
```

### Response fields

| Field | Description |
|---|---|
| `total` | Total INR spot balance |
| `withdrawable` | INR available to transfer or withdraw |
| `coin_investable` | INR available for spot coin purchase |
| `coinset_investable` | INR available for coinset |
| `vault_investable` | INR available for vault |
| `rewards` | Reward balance |
| `invested` | Invested amount |

Balance matched account state after FUTURES → SPOT transfers (`15.67` INR withdrawable at time of test).

---

## Incorrect parameter (for reference)

Using `trade_currency=INR` (as used on futures endpoints) does **not** return the INR spot balance:

```bash
curl -X GET "https://trade.mudrex.com/fapi/v1/wallet/funds?trade_currency=INR" \
  -H "X-Authentication: your-secret-key"
```

**Status:** `200 OK`

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

HTTP 200 with all zeros — misleading if the wrong parameter name is used.

---

## Parameter convention

| Endpoint | Query parameter |
|---|---|
| `GET /wallet/funds` (spot) | `currency=INR` |
| `GET /futures/funds` and all other INR futures endpoints | `trade_currency=INR` |

---

## Conclusion

`GET /wallet/funds?currency=INR` works correctly on production and returns accurate INR spot balances. Use **`currency`**, not **`trade_currency`**, for this endpoint only.
