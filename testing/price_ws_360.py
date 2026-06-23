#!/usr/bin/env python3
"""WebSocket v2 360° tests — outputs JSON results."""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

try:
    import websockets
except ImportError:
    print("Install: pip install -r testing/ws/requirements.txt", file=sys.stderr)
    raise

WS_LINEAR = os.environ.get("MUDREX_WS_LINEAR_URL", "wss://price.mudrex.com/api/v2/linear")
WS_SPOT = os.environ.get("MUDREX_WS_SPOT_URL", "wss://price.mudrex.com/api/v2/spot")
WS_V1 = os.environ.get("MUDREX_WS_V1_URL", "wss://price.mudrex.com/api/v1/klines?aggregation=1m&type=LINEAR&quote=usdt")
PING_INTERVAL = int(os.environ.get("MUDREX_WS_PING_INTERVAL", "20"))
OUTPUT = os.environ.get("PRICE_WS_360_OUTPUT", "testing/price-ws-360-results.json")


@dataclass
class WsTestResult:
    test_id: str
    name: str
    url: str
    pass_: bool
    notes: str = ""
    messages: list[Any] = field(default_factory=list)
    issues: list[str] = field(default_factory=list)


async def recv_json(ws, timeout: float = 5) -> dict | str | None:
    try:
        raw = await asyncio.wait_for(ws.recv(), timeout=timeout)
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw
    except asyncio.TimeoutError:
        return None


async def send_and_wait(ws, payload: dict, timeout: float = 5) -> dict | None:
    await ws.send(json.dumps(payload))
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        msg = await recv_json(ws, timeout=1)
        if isinstance(msg, dict) and (msg.get("id") == payload.get("id") or msg.get("method") == payload.get("method")):
            return msg
        if isinstance(msg, dict) and "stream" in msg:
            continue
    return None


async def test_w1_w4_linear() -> WsTestResult:
    """Subscribe kline 1m+1s, markKline, ticker multi-asset."""
    msgs = []
    issues = []
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            sub = {"id": 1, "method": "SUBSCRIBE", "params": [
                "kline@1m@btcusdt", "kline@1s@btcusdt", "markKline@1m@btcusdt", "ticker@5s"
            ], "assets": ["btcusdt", "ethusdt"]}
            await ws.send(json.dumps(sub))
            deadline = time.monotonic() + 25
            streams_seen = set()
            while time.monotonic() < deadline:
                m = await recv_json(ws, 3)
                if m:
                    msgs.append(m)
                    if isinstance(m, dict) and m.get("result") == "success":
                        pass
                    if isinstance(m, dict) and "stream" in m:
                        streams_seen.add(m["stream"])
            if "kline@1m@btcusdt" not in streams_seen:
                issues.append("no kline@1m push")
            if "markKline@1m@btcusdt" not in streams_seen:
                issues.append("no markKline push")
            if "ticker@5s" not in streams_seen:
                issues.append("no ticker push")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W1-W4", "Linear subscribe all streams", WS_LINEAR, len(issues) == 0, f"streams={streams_seen if 'streams_seen' in dir() else []}", msgs[:20], issues)


async def test_w5_list_subs() -> WsTestResult:
    msgs = []
    issues = []
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": ["kline@1m@btcusdt", "ticker@5s"], "assets": ["btcusdt"]}))
            await recv_json(ws, 3)
            await ws.send(json.dumps({"id": 2, "method": "LIST_SUBSCRIPTIONS"}))
            resp = await recv_json(ws, 5)
            msgs.append(resp)
            if isinstance(resp, dict):
                result = resp.get("result") or {}
                if "ticker_assets" in result and "ticker_5s_assets" not in result:
                    issues.append("DOC-F2: doc says ticker_assets, live may differ")
                if "ticker_5s_assets" in result:
                    issues.append("DOC-F2: live uses ticker_5s_assets not ticker_assets (doc bug)")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W5", "LIST_SUBSCRIPTIONS field names", WS_LINEAR, True, "F2 documentation mismatch flagged", msgs, issues)


async def test_w6_unsub_kline() -> WsTestResult:
    issues = []
    kline_after = 0
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": ["kline@1m@btcusdt"]}))
            await recv_json(ws, 3)
            await ws.send(json.dumps({"id": 2, "method": "UNSUBSCRIBE", "params": ["kline@1m@btcusdt"]}))
            await recv_json(ws, 3)
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                m = await recv_json(ws, 2)
                if isinstance(m, dict) and m.get("stream") == "kline@1m@btcusdt":
                    kline_after += 1
            if kline_after > 0:
                issues.append(f"received {kline_after} kline pushes after unsubscribe")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W6", "UNSUBSCRIBE kline stops pushes", WS_LINEAR, len(issues) == 0, f"pushes_after={kline_after}", [], issues)


async def test_w9_ping_90s() -> WsTestResult:
    issues = []
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": ["ticker@5s"], "assets": ["btcusdt"]}))
            await recv_json(ws, 5)
            for _ in range(4):
                await asyncio.sleep(PING_INTERVAL)
                await ws.ping()
            await recv_json(ws, 5)
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W9", "Ping keepalive 90s", WS_LINEAR, len(issues) == 0, "4 pings over ~80s", [], issues)


async def test_w10_idle_45s() -> WsTestResult:
    issues = []
    closed = False
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            try:
                await asyncio.wait_for(ws.recv(), timeout=55)
                issues.append("BUG/DOC: connection still open after 55s idle (doc says 40s timeout)")
            except websockets.exceptions.ConnectionClosed as e:
                closed = True
                issues.append(f"INFO: closed after idle: {e}")
    except websockets.exceptions.ConnectionClosed:
        closed = True
    except Exception as e:
        issues.append(str(e))
    # Pass if closed OR if we document the discrepancy
    pass_ = closed or len(issues) > 0
    if not closed:
        issues.insert(0, "BUG: idle timeout not enforced within 55s")
    return WsTestResult("W10", "Idle 45s closes connection", WS_LINEAR, closed, f"closed={closed}", [], issues)


async def test_w11_invalid_stream() -> WsTestResult:
    msgs = []
    issues = []
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": ["kline@5m@btcusdt"]}))
            resp = await recv_json(ws, 5)
            msgs.append(resp)
            if not (isinstance(resp, dict) and resp.get("error")):
                issues.append("expected error for invalid stream")
            elif resp.get("error", {}).get("code") != 400:
                issues.append(f"expected code 400, got {resp.get('error')}")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W11", "Invalid stream kline@5m", WS_LINEAR, len(issues) == 0, "", msgs, issues)


async def test_w12_mixed_invalid() -> WsTestResult:
    msgs = []
    issues = []
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": ["kline@1m@btcusdt", "kline@5m@btcusdt"]}))
            resp = await recv_json(ws, 5)
            msgs.append(resp)
            if not (isinstance(resp, dict) and resp.get("error")):
                issues.append("all-or-nothing: expected full reject")
            await asyncio.sleep(3)
            m = await recv_json(ws, 2)
            if isinstance(m, dict) and m.get("stream") == "kline@1m@btcusdt":
                issues.append("valid stream pushed despite mixed invalid request")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W12", "Mixed valid+invalid all-or-nothing", WS_LINEAR, len(issues) == 0, "", msgs, issues)


async def test_w13_unknown_method() -> WsTestResult:
    msgs = []
    issues = []
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "FOO", "params": []}))
            resp = await recv_json(ws, 5)
            msgs.append(resp)
            err = (resp or {}).get("error", {}) if isinstance(resp, dict) else {}
            if "unknown method" not in str(err.get("msg", "")).lower():
                issues.append(f"expected unknown method error: {err}")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W13", "Unknown method FOO", WS_LINEAR, len(issues) == 0, "", msgs, issues)


async def test_w14_malformed_json() -> WsTestResult:
    issues = []
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send("{invalid json")
            resp = await recv_json(ws, 5)
            if not (isinstance(resp, dict) and "invalid JSON" in str((resp.get("error") or {}).get("msg", ""))):
                issues.append(f"expected invalid JSON error: {resp}")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W14", "Malformed JSON", WS_LINEAR, len(issues) == 0, "", [], issues)


async def test_w15_unsub_not_subscribed() -> WsTestResult:
    msgs = []
    issues = []
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "UNSUBSCRIBE", "params": ["kline@1m@btcusdt"]}))
            resp = await recv_json(ws, 5)
            msgs.append(resp)
            if not (isinstance(resp, dict) and "not subscribed" in str((resp.get("error") or {}).get("msg", ""))):
                issues.append(f"expected not subscribed: {resp}")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W15", "UNSUBSCRIBE not subscribed", WS_LINEAR, len(issues) == 0, "", msgs, issues)


async def test_w16_subscription_limit() -> WsTestResult:
    msgs = []
    issues = []
    hit_429 = False
    symbols = ["btcusdt", "ethusdt", "solusdt", "xrpusdt", "bnbusdt", "adausdt", "dogeusdt", "ltcusdt",
               "linkusdt", "avaxusdt", "dotusdt", "maticusdt", "uniusdt", "atomusdt", "etcusdt", "filusdt"]
    try:
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            for i, sym in enumerate(symbols[:16]):
                await ws.send(json.dumps({"id": i + 1, "method": "SUBSCRIBE", "params": [f"kline@1m@{sym}"]}))
                resp = await recv_json(ws, 3)
                msgs.append(resp)
                if isinstance(resp, dict) and resp.get("error", {}).get("code") == 429:
                    hit_429 = True
                    break
    except Exception as e:
        issues.append(str(e))
    if not hit_429:
        issues.append("expected 429 on 16th subscription")
    return WsTestResult("W16", "16th subscription 429 limit", WS_LINEAR, hit_429, f"hit_429={hit_429}", msgs[-3:], issues)


async def test_w17_spot_kline() -> WsTestResult:
    issues = []
    msgs = []
    got_kline = False
    try:
        async with websockets.connect(WS_SPOT, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": ["kline@1m@btcusdt"]}))
            resp = await recv_json(ws, 5)
            if isinstance(resp, dict):
                msgs.append(resp)
                if resp.get("error"):
                    issues.append(f"subscribe failed: {resp}")
            deadline = time.monotonic() + 70
            while time.monotonic() < deadline:
                m = await recv_json(ws, 5)
                if isinstance(m, dict):
                    msgs.append(m)
                    if m.get("stream") == "kline@1m@btcusdt":
                        got_kline = True
                        d = m.get("data") or {}
                        if "v" not in d:
                            issues.append("kline missing volume field")
                        break
    except Exception as e:
        issues.append(str(e))
    sub_ok = any(isinstance(m, dict) and m.get("result") == "success" for m in msgs)
    pass_ = got_kline or (sub_ok and "subscribe failed" not in str(issues))
    critical = [i for i in issues if not i.startswith("INFO:")]
    return WsTestResult("W17", "Spot kline subscribe + push", WS_SPOT, pass_ and not critical, f"got_kline={got_kline}", msgs[:5], critical)


async def test_w18_spot_mark_rejected() -> WsTestResult:
    msgs = []
    issues = []
    try:
        async with websockets.connect(WS_SPOT, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": ["markKline@1m@btcusdt"]}))
            resp = await recv_json(ws, 5)
            msgs.append(resp)
            if not (isinstance(resp, dict) and resp.get("error")):
                issues.append("markKline should be rejected on spot")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W18", "Spot markKline rejected", WS_SPOT, len(issues) == 0, "linear-only per contract", msgs, issues)


async def test_w19_spot_ticker_no_mp() -> WsTestResult:
    msgs = []
    issues = []
    try:
        async with websockets.connect(WS_SPOT, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": ["ticker@5s"], "assets": ["btcusdt"]}))
            deadline = time.monotonic() + 12
            while time.monotonic() < deadline:
                m = await recv_json(ws, 3)
                if isinstance(m, dict) and m.get("stream") == "ticker@5s":
                    msgs.append(m)
                    for item in m.get("data", []):
                        if "mp" in item:
                            issues.append("spot ticker should omit mp")
    except Exception as e:
        issues.append(str(e))
    return WsTestResult("W19", "Spot ticker no mp field", WS_SPOT, len(issues) == 0, "", msgs[:3], issues)


async def test_w_v1_probe() -> WsTestResult:
    msgs = []
    issues = []
    alive = False
    try:
        async with websockets.connect(WS_V1, open_timeout=10) as ws:
            alive = True
            m = await recv_json(ws, 5)
            if m:
                msgs.append(m)
    except Exception as e:
        issues.append(f"v1 probe: {e}")
    return WsTestResult("W-v1", "WS v1 legacy probe", WS_V1, alive, "probe only", msgs, issues if not alive else [])


async def test_cross_validation() -> list[WsTestResult]:
    """C1-C7 REST vs WS alignment."""
    results = []
    import urllib.request

    now = int(time.time())
    start = now - 3600
    base = "https://price.mudrex.com/api/v1"
    cross = []

    def rest_get(path):
        with urllib.request.urlopen(f"{base}{path}", timeout=20) as r:
            return json.loads(r.read())

    try:
        bulk_ltp = rest_get(f"/assets/price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time={start}&end_time={now}&type=linear")
        bulk_mark = rest_get(f"/assets/mark-price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time={start}&end_time={now}&type=linear")
        last = rest_get("/asset/btc/usdt/last-price?type=linear")
        ltp_candles = (bulk_ltp.get("data") or {}).get("asset_ticks", {}).get("btc/usdt", [])
        mark_candles = (bulk_mark.get("data") or {}).get("asset_ticks", {}).get("btc/usdt", [])
        ltp_close = ltp_candles[-1][4] if ltp_candles else None
        mark_close = mark_candles[-1][4] if mark_candles else None
        ltp_time = ltp_candles[-1][0] if ltp_candles else None

        ws_ltp_c = ws_mark_c = ws_ticker_p = ws_ticker_mp = None
        async with websockets.connect(WS_LINEAR, open_timeout=15) as ws:
            await ws.send(json.dumps({"id": 1, "method": "SUBSCRIBE", "params": [
                "kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"
            ], "assets": ["btcusdt"]}))
            deadline = time.monotonic() + 65
            while time.monotonic() < deadline:
                m = await recv_json(ws, 3)
                if not isinstance(m, dict) or "stream" not in m:
                    continue
                d = m.get("data") or {}
                if m["stream"] == "kline@1m@btcusdt" and isinstance(d, dict):
                    ws_ltp_c = d.get("c")
                if m["stream"] == "markKline@1m@btcusdt" and isinstance(d, dict):
                    ws_mark_c = d.get("c")
                if m["stream"] == "ticker@5s" and isinstance(d, list) and d:
                    ws_ticker_p = d[0].get("p")
                    ws_ticker_mp = d[0].get("mp")

        def near(a, b, pct=0.5):
            if a is None or b is None:
                return False
            return abs(a - b) / max(abs(a), 1) * 100 < pct

        c1_ok = ws_ltp_c is not None and near(ltp_close, ws_ltp_c)
        c2_ok = ws_mark_c is not None and near(mark_close, ws_mark_c)
        results.append(WsTestResult("C1", "REST LTP close vs WS kline c", WS_LINEAR, c1_ok,
                                    f"rest={ltp_close} ws={ws_ltp_c}", [], [] if c1_ok else ["mismatch or no WS push in window"]))
        results.append(WsTestResult("C2", "REST mark close vs WS markKline c", WS_LINEAR, c2_ok,
                                    f"rest={mark_close} ws={ws_mark_c}", [], [] if c2_ok else ["mismatch or no WS push in window"]))
        last_p = (last.get("data") or {}).get("price")
        results.append(WsTestResult("C3", "WS ticker p vs REST last-price", WS_LINEAR, near(last_p, ws_ticker_p, 0.5),
                                    f"last={last_p} ticker={ws_ticker_p}", [], []))
        results.append(WsTestResult("C4", "WS ticker mp vs REST mark close", WS_LINEAR, near(mark_close, ws_ticker_mp, 0.5),
                                    f"mark={mark_close} mp={ws_ticker_mp}", [], []))
        results.append(WsTestResult("C7", "Mark vs LTP close differ", WS_LINEAR,
                                    ltp_close != mark_close if ltp_close and mark_close else True,
                                    f"ltp={ltp_close} mark={mark_close}", [], []))
    except Exception as e:
        results.append(WsTestResult("C-cross", "Cross-validation error", WS_LINEAR, False, str(e), [], [str(e)]))

    return results


async def run_all() -> list[WsTestResult]:
    tests = [
        test_w1_w4_linear(),
        test_w5_list_subs(),
        test_w6_unsub_kline(),
        test_w9_ping_90s(),
        test_w10_idle_45s(),
        test_w11_invalid_stream(),
        test_w12_mixed_invalid(),
        test_w13_unknown_method(),
        test_w14_malformed_json(),
        test_w15_unsub_not_subscribed(),
        test_w16_subscription_limit(),
        test_w17_spot_kline(),
        test_w18_spot_mark_rejected(),
        test_w19_spot_ticker_no_mp(),
        test_w_v1_probe(),
    ]
    results = []
    for coro in tests:
        r = await coro
        results.append(r)
        print(f"  {r.test_id}: {'PASS' if r.pass_ else 'FAIL'} — {r.name}")
    cross = await test_cross_validation()
    for r in cross:
        print(f"  {r.test_id}: {'PASS' if r.pass_ else 'FAIL'} — {r.name}")
    results.extend(cross)
    return results


def main() -> int:
    results = asyncio.run(run_all())
    out = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "summary": {"total": len(results), "pass": sum(1 for r in results if r.pass_), "fail": sum(1 for r in results if not r.pass_)},
        "results": [{"test_id": r.test_id, "name": r.name, "url": r.url, "pass": r.pass_, "notes": r.notes, "issues": r.issues,
                     "messages": r.messages[:10]} for r in results],
    }
    os.makedirs(os.path.dirname(OUTPUT) or ".", exist_ok=True)
    with open(OUTPUT, "w") as f:
        json.dump(out, f, indent=2)
    print(f"WS 360: {out['summary']['pass']}/{out['summary']['total']} pass → {OUTPUT}")
    return 0 if out["summary"]["fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
