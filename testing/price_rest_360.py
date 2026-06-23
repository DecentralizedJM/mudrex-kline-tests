#!/usr/bin/env python3
"""REST 360° tests for Data Read Client — outputs JSON results."""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Any

PRICE_BASE = os.environ.get("MUDREX_PRICE_BASE_URL", "https://price.mudrex.com/api/v1")
TRADE_BASE = os.environ.get("MUDREX_BASE_URL", "https://trade.mudrex.com/fapi/v1")
API_SECRET = os.environ.get("MUDREX_API_SECRET", "")
ASSET = os.environ.get("MUDREX_TEST_ASSET", "btc/usdt")
ASSET2 = os.environ.get("MUDREX_TEST_ASSET2", "eth/usdt")
NOW = int(time.time())
START_1H = NOW - 3600
START_24H = NOW - 86400
START_90D = NOW - 90 * 86400
OUTPUT = os.environ.get("PRICE_REST_360_OUTPUT", "testing/price-rest-360-results.json")

LINEAR_AGGS = ["1m", "3t", "5t", "10t", "15t", "30t", "1h", "4h", "6h", "12h", "1d", "1w", "1mth"]


@dataclass
class TestResult:
    test_id: str
    name: str
    url: str
    http_status: int
    pass_: bool
    notes: str = ""
    response: Any = None
    issues: list[str] = field(default_factory=list)


def get(path: str, use_auth: bool = False) -> tuple[int, Any, str]:
    url = f"{PRICE_BASE}{path}"
    headers = {"Accept": "application/json"}
    if use_auth and API_SECRET:
        headers["X-Authentication"] = API_SECRET
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode()
            return resp.status, json.loads(body) if body else None, url
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            data = json.loads(body) if body else {"raw": body}
        except json.JSONDecodeError:
            data = {"raw": body}
        return e.code, data, url
    except Exception as e:
        return 0, {"error": str(e)}, url


def validate_candles(data: dict, ltp: bool) -> list[str]:
    issues = []
    ticks = (data.get("data") or {}).get("asset_ticks") or {}
    expected_len = 6 if ltp else 5
    for asset, candles in ticks.items():
        if not candles:
            issues.append(f"{asset}: empty candle list")
            continue
        times = []
        for c in candles:
            if len(c) != expected_len:
                issues.append(f"{asset}: candle has {len(c)} fields, expected {expected_len}")
            if len(c) >= 5:
                t, o, h, l, cl = c[0], c[1], c[2], c[3], c[4]
                times.append(t)
                if h < l:
                    issues.append(f"{asset}@{t}: high < low")
                if not (l <= o <= h and l <= cl <= h):
                    issues.append(f"{asset}@{t}: open/close outside high-low range")
            if ltp and len(c) >= 6 and c[5] < 0:
                issues.append(f"{asset}@{c[0]}: negative volume")
        if times != sorted(times):
            issues.append(f"{asset}: candles not ascending by time")
        if len(times) != len(set(times)):
            issues.append(f"{asset}: duplicate open times")
        if ltp and len(times) >= 2:
            for i in range(1, min(5, len(times))):
                gap = times[i] - times[i - 1]
                if 50 < gap < 70:
                    pass  # ~1m ok
    return issues


def run_test(test_id: str, name: str, path: str, expect_http: int | range = 200,
             validate_ltp: bool | None = None, expect_success: bool = True,
             notes: str = "", external_only: bool = False,
             flag_issues: list[str] | None = None) -> TestResult:
    status, data, url = get(path)
    ok_http = status == expect_http if isinstance(expect_http, int) else expect_http.start <= status <= expect_http.stop
    issues = list(flag_issues or [])
    pass_ = ok_http

    if validate_ltp is not None and status == 200 and isinstance(data, dict) and not external_only:
        if data.get("success") is False and expect_success:
            pass_ = False
            issues.append("success=false")
        else:
            issues.extend(validate_candles(data, validate_ltp))

    if external_only and status == 200 and isinstance(data, dict):
        ticks = (data.get("data") or {}).get("asset_ticks", {}).get(ASSET, [])
        if ticks and any(len(c) >= 4 and c[1] == 0 and c[2] == 0 and c[3] == 0 for c in ticks):
            issues.append("PM-F1: external params return o,h,l=0 — close-only at index 4")
            pass_ = False

    if expect_success and status == 200 and isinstance(data, dict) and not data.get("success", True):
        pass_ = False
        issues.append("success=false in body")

    if issues:
        critical = [i for i in issues if not i.startswith("INFO:")]
        if critical:
            pass_ = False

    return TestResult(test_id, name, url, status, pass_, notes, data, issues)


def main() -> int:
    results: list[TestResult] = []

    # 2A Bulk
    full = f"&ohlcv=true&partial=true&type=linear"
    ext = ""
    w1h = f"&start_time={START_1H}&end_time={NOW}"
    w24h = f"&start_time={START_24H}&end_time={NOW}"
    w90d = f"&start_time={START_90D}&end_time={NOW}"

    results.append(run_test("R1", "Bulk LTP full params", f"/assets/price?assets={ASSET}&aggregation=1m{w1h}{full}", validate_ltp=True))
    results.append(run_test("R2", "Bulk mark full params", f"/assets/mark-price?assets={ASSET}&aggregation=1m{w1h}{full}", validate_ltp=False))
    results.append(run_test("R3", "Bulk LTP external-only (4 params)", f"/assets/price?assets={ASSET}&aggregation=1m{w1h}",
                            external_only=True, notes="F1: PM external param set"))
    results.append(run_test("R4", "Bulk mark external-only", f"/assets/mark-price?assets={ASSET}&aggregation=1m{w1h}",
                            external_only=True))
    results.append(run_test("R5", "Multi-asset bulk LTP", f"/assets/price?assets={ASSET},{ASSET2}&aggregation=1m{w1h}{full}", validate_ltp=True))
    results.append(run_test("R6a", "Bulk LTP partial=true", f"/assets/price?assets={ASSET}&aggregation=1m{w1h}&ohlcv=true&partial=true&type=linear", validate_ltp=True))
    results.append(run_test("R6b", "Bulk LTP partial=false", f"/assets/price?assets={ASSET}&aggregation=1m{w1h}&ohlcv=true&partial=false&type=linear", validate_ltp=True))
    results.append(run_test("R7a", "Bulk LTP type=linear", f"/assets/price?assets={ASSET}&aggregation=1m{w1h}{full}", validate_ltp=True))
    results.append(run_test("R7b", "Bulk LTP type=spot", f"/assets/price?assets={ASSET}&aggregation=1m{w1h}&ohlcv=true&partial=true&type=spot", validate_ltp=True))

    # 2B Single-asset
    base = f"/asset/btc/usdt"
    results.append(run_test("R8", "Single LTP klines", f"{base}/klines?start_time={START_1H}&end_time={NOW}&aggregation=1m&ohlcv=true&type=linear", validate_ltp=True))
    r9 = run_test("R9", "Single mark klines", f"{base}/mark-price?start_time={START_1H}&end_time={NOW}&aggregation=1m&ohlcv=true", validate_ltp=False)
    if r9.http_status == 404:
        r9.issues.append("BUG: single-asset mark-price path returns 404 — bulk works")
    results.append(r9)
    results.append(run_test("R10", "Last price LTP", f"{base}/last-price?type=linear", expect_success=True))
    results.append(run_test("R11", "Point price no ohlcv", f"{base}/price?type=linear", expect_success=True))

    # R12 bulk vs single
    _, bulk_ltp, _ = get(f"/assets/price?assets={ASSET}&aggregation=1m&start_time={START_1H}&end_time={NOW}{full}")
    _, single_ltp, _ = get(f"{base}/klines?start_time={START_1H}&end_time={NOW}&aggregation=1m&ohlcv=true&type=linear")
    bulk_close = None
    single_close = None
    try:
        bulk_c = (bulk_ltp.get("data") or {}).get("asset_ticks", {}).get(ASSET, [])
        single_c = (single_ltp.get("data") or {}).get("asset_ticks", {}).get(ASSET, [])
        if not single_c:
            single_c = (single_ltp.get("data") or {}).get("ticks", [])
        if bulk_c:
            bulk_close = bulk_c[-1][4]
        if single_c:
            single_close = single_c[-1][4]
    except (TypeError, KeyError, IndexError):
        pass
    r12_pass = bulk_close is not None and single_close is not None and abs(bulk_close - single_close) < 0.01
    results.append(TestResult("R12", "Bulk vs single LTP close", f"{PRICE_BASE}/assets/price vs {base}/klines",
                              200, r12_pass, f"bulk={bulk_close} single={single_close}",
                              {"bulk_close": bulk_close, "single_close": single_close},
                              [] if r12_pass else ["bulk/single close mismatch"]))

    # 2C Aggregation sweep
    for agg in LINEAR_AGGS:
        window = w90d if agg in ("1w", "1mth") else w24h
        r = run_test(f"R-agg-{agg}", f"Aggregation {agg}", f"/assets/price?assets={ASSET}&aggregation={agg}{window}{full}",
                     validate_ltp=True, notes="90d window for 1w/1mth else 24h")
        if agg in ("1w", "1mth") and r.http_status == 200:
            ticks = (r.response or {}).get("data", {}).get("asset_ticks", {}).get(ASSET, []) if r.response else []
            if not ticks:
                r.issues.append("INFO: empty on window — may need longer range")
                r.pass_ = True  # not a failure if empty with short window
        results.append(r)
        time.sleep(0.3)

    # 2D Time boundaries
    minute = NOW - (NOW % 60)
    results.append(run_test("R13", "start_time == end_time", f"/assets/price?assets={ASSET}&aggregation=1m&start_time={minute}&end_time={minute}{full}"))
    results.append(run_test("R14", "start_time > end_time", f"/assets/price?assets={ASSET}&aggregation=1m&start_time={NOW}&end_time={START_1H}{full}", expect_http=range(200, 500)))
    results.append(run_test("R15", "Future end_time", f"/assets/price?assets={ASSET}&aggregation=1m&start_time={NOW}&end_time={NOW+86400}{full}"))
    results.append(run_test("R16", "Very old range 2020", f"/assets/price?assets={ASSET}&aggregation=1d&start_time=1577836800&end_time=1577923200{full}"))
    r17 = run_test("R17", "1s klines duration=300", f"{base}/klines?aggregation=1s&duration=300&ohlcv=true&type=linear", validate_ltp=True)
    if r17.http_status == 404 or (isinstance(r17.response, dict) and not r17.response.get("success", True)):
        r17.issues.append("BUG: single-asset 1s klines not found — check path or type param")
        r17.pass_ = False
    results.append(r17)

    # 2E Negative
    results.append(run_test("R18", "Invalid asset foo/bar", f"/assets/price?assets=foo/bar&aggregation=1m{w1h}{full}", expect_http=range(200, 500), expect_success=False))
    results.append(run_test("R19", "Invalid aggregation 99x", f"/assets/price?assets={ASSET}&aggregation=99x{w1h}{full}", expect_http=range(400, 500), expect_success=False))
    results.append(run_test("R20", "Asset format btcusdt no slash", f"/assets/price?assets=btcusdt&aggregation=1m{w1h}{full}"))
    results.append(run_test("R21", "Uppercase BTC/USDT", f"/assets/price?assets=BTC/USDT&aggregation=1m{w1h}{full}"))
    r22 = run_test("R22", "Missing start_time", f"/assets/price?assets={ASSET}&aggregation=1m&end_time={NOW}{full}",
                   expect_http=range(400, 500), expect_success=False)
    if r22.http_status == 200:
        r22.issues.append("BUG: missing start_time returns 200 (point price) instead of 400")
        r22.pass_ = False
    results.append(r22)
    results.append(run_test("R23", "Mark bulk type=spot", f"/assets/mark-price?assets={ASSET}&aggregation=1m{w1h}&ohlcv=true&partial=true&type=spot", validate_ltp=False))

    # C8 trading API cross
    if API_SECRET:
        trade_url = f"{TRADE_BASE}/futures/BTCUSDT?is_symbol"
        req = urllib.request.Request(trade_url, headers={"X-Authentication": API_SECRET})
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                trade_data = json.loads(resp.read().decode())
            trade_price = float((trade_data.get("data") or {}).get("price", 0))
            last_data = results[[r.test_id for r in results].index("R10")].response if "R10" in [r.test_id for r in results] else None
            last_price = float((last_data.get("data") or {}).get("price", 0)) if last_data else 0
            diff_pct = abs(trade_price - last_price) / trade_price * 100 if trade_price else 999
            c8_pass = diff_pct < 1.0
            results.append(TestResult("C8", "Trading API price vs last-price", trade_url, 200, c8_pass,
                                      f"trade={trade_price} last={last_price} diff={diff_pct:.3f}%",
                                      {"trade_price": trade_price, "last_price": last_price}, [] if c8_pass else [">1% diff"]))
        except Exception as e:
            results.append(TestResult("C8", "Trading API price vs last-price", trade_url, 0, False, str(e)))

    out = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "base": PRICE_BASE,
        "summary": {
            "total": len(results),
            "pass": sum(1 for r in results if r.pass_),
            "fail": sum(1 for r in results if not r.pass_),
        },
        "results": [
            {
                "test_id": r.test_id,
                "name": r.name,
                "url": r.url,
                "http_status": r.http_status,
                "pass": r.pass_,
                "notes": r.notes,
                "issues": r.issues,
                "response": r.response if r.response and len(json.dumps(r.response)) < 8000 else "(truncated)",
            }
            for r in results
        ],
    }

    os.makedirs(os.path.dirname(OUTPUT) or ".", exist_ok=True)
    with open(OUTPUT, "w") as f:
        json.dump(out, f, indent=2)

    print(f"REST 360: {out['summary']['pass']}/{out['summary']['total']} pass → {OUTPUT}")
    return 0 if out["summary"]["fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
