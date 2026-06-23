#!/usr/bin/env python3
"""
Mudrex Price WebSocket API v2 test harness.

Contract: docs/price-websocket-v2-contract.md
Linear (futures): wss://price.mudrex.com/api/v2/linear
Spot: wss://price.mudrex.com/api/v2/spot
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

try:
    import websockets
except ImportError:
    print("Install deps: pip install -r testing/ws/requirements.txt", file=sys.stderr)
    raise

DEFAULT_WS_LINEAR = os.environ.get(
    "MUDREX_WS_LINEAR_URL", "wss://price.mudrex.com/api/v2/linear"
)
DEFAULT_WS_SPOT = os.environ.get(
    "MUDREX_WS_SPOT_URL", "wss://price.mudrex.com/api/v2/spot"
)
PING_INTERVAL = int(os.environ.get("MUDREX_WS_PING_INTERVAL", "20"))


def stream_kline(symbol: str, interval: str = "1m") -> str:
    return f"kline@{interval}@{symbol.lower()}"


def stream_mark_kline(symbol: str, interval: str = "1m") -> str:
    return f"markKline@{interval}@{symbol.lower()}"


def build_message(msg_id: int, method: str, params: list[str], assets: list[str] | None = None) -> str:
    payload: dict = {"id": msg_id, "method": method, "params": params}
    if assets is not None:
        payload["assets"] = assets
    return json.dumps(payload)


async def ping_loop(ws) -> None:
    while True:
        await asyncio.sleep(PING_INTERVAL)
        await ws.ping()
        print(f"[ping] {datetime.now(timezone.utc).isoformat()}")


async def run_test(
    ws_url: str,
    subscribe_params: list[str],
    assets: list[str] | None,
    duration: int,
    out_path: Path | None,
    list_subs: bool,
) -> int:
    messages: list[dict] = []
    msg_id = 1

    print(f"Connecting to {ws_url}")
    print(f"Subscribe params: {subscribe_params}")
    if assets:
        print(f"Assets (ticker): {assets}")
    print(f"Duration: {duration}s | Ping interval: {PING_INTERVAL}s")
    print("---")

    try:
        async with websockets.connect(ws_url, open_timeout=15) as ws:
            ping_task = asyncio.create_task(ping_loop(ws))

            sub = build_message(msg_id, "SUBSCRIBE", subscribe_params, assets)
            msg_id += 1
            print(f"→ {sub}")
            await ws.send(sub)

            deadline = time.monotonic() + min(10, duration)
            while time.monotonic() < deadline:
                raw = await asyncio.wait_for(ws.recv(), timeout=5)
                ts = datetime.now(timezone.utc).isoformat()
                print(f"[{ts}] {raw[:800]}")
                try:
                    messages.append({"ts": ts, "msg": json.loads(raw)})
                except json.JSONDecodeError:
                    messages.append({"ts": ts, "raw": raw})
                if any(
                    isinstance(m.get("msg"), dict) and m["msg"].get("result") == "success"
                    for m in messages[-1:]
                ):
                    break

            if list_subs:
                lst = build_message(msg_id, "LIST_SUBSCRIPTIONS", [])
                msg_id += 1
                print(f"→ {lst}")
                await ws.send(lst)

            listen_until = time.monotonic() + duration
            while time.monotonic() < listen_until:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=5)
                except asyncio.TimeoutError:
                    continue
                ts = datetime.now(timezone.utc).isoformat()
                print(f"[{ts}] {raw[:800]}")
                try:
                    messages.append({"ts": ts, "msg": json.loads(raw)})
                except json.JSONDecodeError:
                    messages.append({"ts": ts, "raw": raw})

            ping_task.cancel()
            try:
                await ping_task
            except asyncio.CancelledError:
                pass

    except Exception as exc:
        print(f"WebSocket error: {exc}", file=sys.stderr)
        return 1

    pushes = [m for m in messages if isinstance(m.get("msg"), dict) and "stream" in m["msg"]]
    print("---")
    print(f"Total messages: {len(messages)} | Stream pushes: {len(pushes)}")

    if out_path:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            for row in messages:
                f.write(json.dumps(row) + "\n")
        print(f"Saved to {out_path}")

    return 0 if messages else 2


def main() -> int:
    parser = argparse.ArgumentParser(description="Mudrex Price WebSocket v2 test")
    parser.add_argument("--market", choices=["linear", "spot"], default="linear")
    parser.add_argument("--url", default="", help="Override WebSocket URL")
    parser.add_argument("--symbol", default="btcusdt", help="Lowercase symbol e.g. btcusdt")
    parser.add_argument(
        "--streams",
        default="kline,markKline,ticker",
        help="Comma-separated: kline, markKline, ticker",
    )
    parser.add_argument("--interval", default="1m", choices=["1s", "1m"])
    parser.add_argument("--duration", type=int, default=45)
    parser.add_argument("--list-subs", action="store_true")
    parser.add_argument("--out", default="testing/ws/price-v2-capture.jsonl")
    args = parser.parse_args()

    ws_url = args.url or (DEFAULT_WS_LINEAR if args.market == "linear" else DEFAULT_WS_SPOT)
    sym = args.symbol.lower()
    kinds = [s.strip() for s in args.streams.split(",") if s.strip()]

    params: list[str] = []
    assets: list[str] | None = None

    for kind in kinds:
        if kind == "kline":
            params.append(stream_kline(sym, args.interval))
        elif kind == "markKline":
            if args.market != "linear":
                print("markKline is linear-only", file=sys.stderr)
                return 1
            params.append(stream_mark_kline(sym, args.interval))
        elif kind == "ticker":
            params.append("ticker@5s")
            assets = [sym]

    if not params:
        print("No streams selected", file=sys.stderr)
        return 1

    out = Path(args.out) if args.out else None
    return asyncio.run(run_test(ws_url, params, assets, args.duration, out, args.list_subs))


if __name__ == "__main__":
    raise SystemExit(main())
