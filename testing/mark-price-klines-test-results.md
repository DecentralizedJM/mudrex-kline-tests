# Mark Price & LTP Klines — Test Results

Generated: 2026-06-17T05:37:30Z
Base URL: https://trade.mudrex.com/fapi/v1
Symbol: BTCUSDT

> Update `KLINES_PATH` and `price_type` in `run_mark_price_klines_tests.sh` if the contract differs.

## 0. Endpoint exists (base klines path)

| Field | Value |
|---|---|
| Method | `GET` |
| Path | `/futures/BTCUSDT/klines?is_symbol&interval=1m&limit=3` |
| HTTP | **404** |

```json
{
    "code": 404,
    "text": "requested resource was not found"
}

```

---

## 1. Mark price klines

| Field | Value |
|---|---|
| Method | `GET` |
| Path | `/futures/BTCUSDT/klines?is_symbol&interval=1m&limit=10&price_type=mark` |
| HTTP | **404** |

**Query / params:** `interval=1m, limit=10&price_type=mark`

```json
{
    "code": 404,
    "text": "requested resource was not found"
}

```

---

## 2. LTP klines

| Field | Value |
|---|---|
| Method | `GET` |
| Path | `/futures/BTCUSDT/klines?is_symbol&interval=1m&limit=10&price_type=ltp` |
| HTTP | **404** |

**Query / params:** `interval=1m, limit=10&price_type=ltp`

```json
{
    "code": 404,
    "text": "requested resource was not found"
}

```

---

## 3. Invalid price type

| Field | Value |
|---|---|
| Method | `GET` |
| Path | `/futures/BTCUSDT/klines?is_symbol&interval=1m&limit=10&price_type=invalid_type_xyz` |
| HTTP | **404** |

**Query / params:** `interval=1m, limit=10&price_type=invalid_type_xyz`

```json
{
    "code": 404,
    "text": "requested resource was not found"
}

```

---

## 4. Invalid interval

| Field | Value |
|---|---|
| Method | `GET` |
| Path | `/futures/BTCUSDT/klines?is_symbol&interval=99x&limit=3&price_type=mark` |
| HTTP | **404** |

```json
{
    "code": 404,
    "text": "requested resource was not found"
}

```

---

## 5. Invalid symbol

| Field | Value |
|---|---|
| Method | `GET` |
| Path | `/futures/NOTASymbol/klines?is_symbol&interval=1m&limit=3&price_type=mark` |
| HTTP | **404** |

```json
{
    "code": 404,
    "text": "requested resource was not found"
}

```

---

## 6. Mark vs LTP comparison

- Mark response type: `dict`
- LTP response type: `dict`
- **Warning:** Mark and LTP responses are identical — verify price_type filter works.

