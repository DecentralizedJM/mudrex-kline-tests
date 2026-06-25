# Test Report: FAPI v1 Market Data API

## Document control

| Field | Value |
|-------|-------|
| Report ID | TR-FAPI-MD-20260625 |
| Document under test | [Market Data API Reference](https://mudrex.atlassian.net/wiki/x/EwDVj) |
| Test type | API validation — documentation conformance |
| Environment | Production |
| Execution window | 2026-06-25 11:01:05 UTC → 2026-06-25 11:03:53 UTC |
| Executed by | Automated harness (`testing/fapi_market_data_test.py`) |
| Overall result | **PASS** (20/20 test cases passed) |

## 1. Purpose

Verify that the production FAPI v1 public market-data API behaves as specified in the published technical documentation.

## 2. Scope

**In scope:** REST klines/mark-klines; WebSocket price streams, mark streams, ticker; error handling; subscription lifecycle; keepalive.

**Out of scope:** Authenticated Trade API; legacy price.mudrex.com; rate-limit load testing.

## 3. Test approach

Automated black-box testing. Each test case maps to a documentation section. Validates HTTP status, JSON schema, field types, and WebSocket control responses. No credentials sent.

## 4. Test environment

| Component | Value |
|-----------|-------|
| REST base URL | `https://trade.mudrex.com/fapi/v1/price` |
| WebSocket URL | `wss://trade.mudrex.com/fapi/v1/price/ws/linear` |
| Test assets | `BTC/USDT`, `BTC/USDT,ETH/USDT` |
| WS symbols | `btcusdt`, `ethusdt` |
| Time window | 1782381665 – 1782385265 (epoch s) |
| Aggregation | `1m` |

## 5. Summary of results

| Category | Planned | Executed | Passed | Failed |
|----------|---------|----------|--------|--------|
| REST | 12 | 12 | 12 | 0 |
| WebSocket | 8 | 8 | 8 | 0 |
| **Total** | **20** | **20** | **20** | **0** |

## 6. Test case summary

| TC ID | Title | Category | Priority | Doc § | Result |
|-------|-------|----------|----------|-------|--------|
| TC-REST-001 | Fetch single-asset price klines | REST / Kline | P1 | §3.1 | PASS |
| TC-REST-002 | Fetch bulk price klines (≤25 assets) | REST / Kline | P1 | §3.1 | PASS |
| TC-REST-003 | Response symbol keys are lowercase | REST / Kline | P2 | §3.1 | PASS |
| TC-REST-004 | Fetch single-asset mark-price klines | REST / Mark Kline | P1 | §3.2 | PASS |
| TC-REST-005 | Fetch bulk mark-price klines | REST / Mark Kline | P1 | §3.2 | PASS |
| TC-REST-006 | All documented aggregation intervals accepted | REST / Kline | P1 | §3.1 | PASS |
| TC-REST-007 | Error when assets parameter omitted | REST / Errors | P1 | §6.1 | PASS |
| TC-REST-008 | Error when >25 assets requested | REST / Errors | P2 | §6.1 | PASS |
| TC-REST-009 | Error on unsupported aggregation | REST / Errors | P2 | §6.1 | PASS |
| TC-REST-010 | Error when end_time ≤ start_time | REST / Errors | P2 | §6.1 | PASS |
| TC-REST-011 | REST error envelope structure | REST / Errors | P1 | §6.1 | PASS |
| TC-REST-012 | Query params match documentation | REST / Kline | P1 | §3.1 | PASS |
| TC-WS-001 | WebSocket SUBSCRIBE success response | WebSocket | P1 | §4.4/§4.6 | PASS |
| TC-WS-002 | Price kline push payload (kline@1s) | WebSocket | P1 | §4.9 | PASS |
| TC-WS-003 | Mark kline push payload (markKline@1m) | WebSocket | P1 | §4.9 | PASS |
| TC-WS-004 | Ticker subscribe — snapshot and delta pushes | WebSocket | P1 | §4.6/§4.9 | PASS |
| TC-WS-005 | LIST_SUBSCRIPTIONS response shape | WebSocket | P2 | §4.8 | PASS |
| TC-WS-006 | UNSUBSCRIBE removes stream | WebSocket | P2 | §4.7 | PASS |
| TC-WS-007 | Connection keepalive beyond 40s idle | WebSocket | P1 | §4.2 | PASS |
| TC-WS-008 | Invalid stream rejected (all-or-nothing) | WebSocket | P2 | §6.2 | PASS |

## 7. Detailed test cases

### TC-REST-001: Fetch single-asset price klines

**Status:** PASS  
**Category:** REST / Kline · **Priority:** P1 · **Doc §:** §3.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable; no auth header.

**Test steps:**

1. GET /kline with assets=BTC/USDT, aggregation=1m, start_time, end_time (last 1h).

2. Parse JSON response.

**Expected result:** HTTP 200; success=true; data.asset_ticks['btc/usdt'] present; each candle is 6-element array [t,o,h,l,c,v]; open times ascending; ≤1440 candles.

**Actual result:** 1 asset(s), 6-element candles OK

---

### TC-REST-002: Fetch bulk price klines (≤25 assets)

**Status:** PASS  
**Category:** REST / Kline · **Priority:** P1 · **Doc §:** §3.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable; no auth header.

**Test steps:**

1. GET /kline with assets=BTC/USDT,ETH/USDT and valid time window.

2. Verify both symbols returned.

**Expected result:** HTTP 200; keys btc/usdt and eth/usdt both present with valid 6-element candles.

**Actual result:** 2 asset(s), 6-element candles OK

---

### TC-REST-003: Response symbol keys are lowercase

**Status:** PASS  
**Category:** REST / Kline · **Priority:** P2 · **Doc §:** §3.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable.

**Test steps:**

1. Request assets=BTC/USDT (uppercase).

2. Inspect response keys.

**Expected result:** Response map keys are lowercase (btc/usdt); uppercase key absent.

**Actual result:** keys=['btc/usdt']

---

### TC-REST-004: Fetch single-asset mark-price klines

**Status:** PASS  
**Category:** REST / Mark Kline · **Priority:** P1 · **Doc §:** §3.2  
**Endpoint:** `GET /fapi/v1/price/mark-kline`  

**Preconditions:** Production reachable; no auth header.

**Test steps:**

1. GET /mark-kline with assets=BTC/USDT, aggregation=1m, start_time, end_time.

2. Validate candle structure.

**Expected result:** HTTP 200; success=true; btc/usdt present; each candle is 5-element array (no volume).

**Actual result:** 1 asset(s), 5-element candles OK (per doc example)

---

### TC-REST-005: Fetch bulk mark-price klines

**Status:** PASS  
**Category:** REST / Mark Kline · **Priority:** P1 · **Doc §:** §3.2  
**Endpoint:** `GET /fapi/v1/price/mark-kline`  

**Preconditions:** Production reachable.

**Test steps:**

1. GET /mark-kline with assets=BTC/USDT,ETH/USDT.

2. Validate both symbols.

**Expected result:** HTTP 200; btc/usdt and eth/usdt returned with 5-element mark candles.

**Actual result:** 2 asset(s), 5-element candles OK (per doc example)

---

### TC-REST-006: All documented aggregation intervals accepted

**Status:** PASS  
**Category:** REST / Kline · **Priority:** P1 · **Doc §:** §3.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable.

**Test steps:**

1. For each interval in {1m,3t,5t,10t,15t,30t,1h,4h,6h,12h,1d,1w,1mth}, call /kline.

2. Record HTTP status.

**Expected result:** HTTP 200 and success=true for all 13 documented intervals.

**Actual result:** all accepted

---

### TC-REST-007: Error when assets parameter omitted

**Status:** PASS  
**Category:** REST / Errors · **Priority:** P1 · **Doc §:** §6.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable.

**Test steps:**

1. GET /kline without assets; include aggregation, start_time, end_time.

**Expected result:** HTTP 400; success=false; errors[0].text = 'assets are required'.

**Actual result:** HTTP 400, texts=['assets are required'], envelope=errors[0].code=400, errors[0].text='assets are required'

---

### TC-REST-008: Error when >25 assets requested

**Status:** PASS  
**Category:** REST / Errors · **Priority:** P2 · **Doc §:** §6.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable.

**Test steps:**

1. GET /kline with 26 comma-separated asset pairs.

**Expected result:** HTTP 400; errors[0].text = 'allowed assets size is 25'.

**Actual result:** HTTP 400, texts=['allowed assets size is 25'], envelope=errors[0].code=400, errors[0].text='allowed assets size is 25'

---

### TC-REST-009: Error on unsupported aggregation

**Status:** PASS  
**Category:** REST / Errors · **Priority:** P2 · **Doc §:** §6.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable.

**Test steps:**

1. GET /kline with aggregation=5x.

**Expected result:** HTTP 400; error text indicates aggregation not supported.

**Actual result:** HTTP 400, texts=['5x aggregation not supported'], envelope=errors[0].code=400, errors[0].text='5x aggregation not supported'

---

### TC-REST-010: Error when end_time ≤ start_time

**Status:** PASS  
**Category:** REST / Errors · **Priority:** P2 · **Doc §:** §6.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable.

**Test steps:**

1. GET /kline with start_time >= end_time.

**Expected result:** HTTP 400; errors[0].text = 'end time should be greater than start time'.

**Actual result:** HTTP 400, texts=['end time should be greater than start time'], envelope=errors[0].code=400, errors[0].text='end time should be greater than start time'

---

### TC-REST-011: REST error envelope structure

**Status:** PASS  
**Category:** REST / Errors · **Priority:** P1 · **Doc §:** §6.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Production reachable; trigger a 400 (assets omitted).

**Test steps:**

1. Send invalid request.

2. Inspect error JSON envelope.

**Expected result:** success=false; errors array present; each item has code (int) and text (string).

**Actual result:** errors[0].code=400, errors[0].text='assets are required'

---

### TC-REST-012: Query params match documentation

**Status:** PASS  
**Category:** REST / Kline · **Priority:** P1 · **Doc §:** §3.1  
**Endpoint:** `GET /fapi/v1/price/kline`  

**Preconditions:** Doc specifies aggregation, start_time, end_time.

**Test steps:**

1. GET /kline using aggregation, start_time, end_time (snake_case).

2. Confirm data returned.

**Expected result:** HTTP 200; success=true; asset_ticks populated.

**Actual result:** HTTP 200, data=yes

---

### TC-WS-001: WebSocket SUBSCRIBE success response

**Status:** PASS  
**Category:** WebSocket · **Priority:** P1 · **Doc §:** §4.4/§4.6  
**Endpoint:** `wss://…/price/ws/linear`  

**Preconditions:** WS connection open; no auth.

**Test steps:**

1. Connect to WS linear endpoint.

2. Send SUBSCRIBE for kline@1m, kline@1s, markKline@1m.

3. Await control response.

**Expected result:** Response received before push data: { method, id, result: 'success' }.

**Actual result:** {'method': 'SUBSCRIBE', 'id': 1, 'result': 'success'}

---

### TC-WS-002: Price kline push payload (kline@1s)

**Status:** PASS  
**Category:** WebSocket · **Priority:** P1 · **Doc §:** §4.9  
**Endpoint:** `wss://…/price/ws/linear`  

**Preconditions:** Subscribed to kline@1s@ethusdt.

**Test steps:**

1. Listen for stream pushes up to 75s.

2. Inspect first kline@1s push.

**Expected result:** Envelope { stream, data }; data contains s,t,o,h,l,c,v; s=ethusdt; t is epoch seconds.

**Actual result:** 61 pushes, t=1782385276

---

### TC-WS-003: Mark kline push payload (markKline@1m)

**Status:** PASS  
**Category:** WebSocket · **Priority:** P1 · **Doc §:** §4.9  
**Endpoint:** `wss://…/price/ws/linear`  

**Preconditions:** Subscribed to markKline@1m@btcusdt.

**Test steps:**

1. Listen for markKline pushes.

2. Inspect payload fields.

**Expected result:** Envelope { stream, data }; data has s,t,o,h,l,c; volume field v absent.

**Actual result:** 1 pushes, t=1782385260

---

### TC-WS-004: Ticker subscribe — snapshot and delta pushes

**Status:** PASS  
**Category:** WebSocket · **Priority:** P1 · **Doc §:** §4.6/§4.9  
**Endpoint:** `wss://…/price/ws/linear`  

**Preconditions:** WS connection open.

**Test steps:**

1. SUBSCRIBE ticker@5s with assets=[btcusdt,ethusdt].

2. Observe first message (snapshot).

3. Observe subsequent pushes within 35s.

**Expected result:** Immediate snapshot with s and p per asset; mp present on linear; later pushes only for changed assets.

**Actual result:** snapshot=2 items, mp_present=True, later_pushes=7

---

### TC-WS-005: LIST_SUBSCRIPTIONS response shape

**Status:** PASS  
**Category:** WebSocket · **Priority:** P2 · **Doc §:** §4.8  
**Endpoint:** `wss://…/price/ws/linear`  

**Preconditions:** Active subscriptions on connection.

**Test steps:**

1. Send LIST_SUBSCRIPTIONS.

2. Inspect result object.

**Expected result:** result.subscriptions array returned; ticker_5s_assets lists tracked symbols.

**Actual result:** subs=['kline@1m@btcusdt', 'kline@1s@ethusdt', 'markKline@1m@btcusdt', 'ticker@5s'], ticker_5s_assets=['btcusdt', 'ethusdt']

---

### TC-WS-006: UNSUBSCRIBE removes stream

**Status:** PASS  
**Category:** WebSocket · **Priority:** P2 · **Doc §:** §4.7  
**Endpoint:** `wss://…/price/ws/linear`  

**Preconditions:** kline@1m@btcusdt currently subscribed.

**Test steps:**

1. UNSUBSCRIBE kline@1m@btcusdt.

2. LIST_SUBSCRIPTIONS to confirm removal.

**Expected result:** UNSUBSCRIBE returns success; stream no longer in subscriptions list.

**Actual result:** remaining=['kline@1s@ethusdt', 'markKline@1m@btcusdt', 'ticker@5s']

---

### TC-WS-007: Connection keepalive beyond 40s idle

**Status:** PASS  
**Category:** WebSocket · **Priority:** P1 · **Doc §:** §4.2  
**Endpoint:** `wss://…/price/ws/linear`  

**Preconditions:** PING sent every 20s; no other messages.

**Test steps:**

1. Maintain connection with PING frames only.

2. Wait 45s.

3. Confirm connection still open.

**Expected result:** Connection remains open past 40s inactivity threshold.

**Actual result:** open 45s

---

### TC-WS-008: Invalid stream rejected (all-or-nothing)

**Status:** PASS  
**Category:** WebSocket · **Priority:** P2 · **Doc §:** §6.2  
**Endpoint:** `wss://…/price/ws/linear`  

**Preconditions:** WS connection open with existing subscriptions.

**Test steps:**

1. SUBSCRIBE kline@5m@btcusdt (unsupported interval).

2. LIST_SUBSCRIPTIONS.

**Expected result:** Error { code:400, msg:'invalid stream name:…' }; invalid stream not added to subscriptions.

**Actual result:** error={'code': 400, 'msg': 'invalid stream name: kline@5m@btcusdt'}

---

## 8. Observations

- REST errors return `errors[]` with `code` and `text` (Doc §6.1).
- Query params: `aggregation`, `start_time`, `end_time` (snake_case).
- Mark klines: 5-element candles; price klines: 6-element candles.

## 9. Conclusion

All 20 test cases passed. Production API is consistent with the published technical documentation.
