#!/usr/bin/env python3
"""
Mudrex price WebSocket test harness.

Update WS_URL and SUBSCRIBE_TEMPLATE when engineering confirms the contract.
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

# --- Contract config (edit when engineer confirms) ---
DEFAULT_WS_URL = os.environ.get("MUDREX_WS_URL", "wss://trade.mudrex.com/fapi/v1/ws")
DEFAULT_SYMBOL = os.environ.get("MUDREX_TEST_SYMBOL", "BTCUSDT")

# Example subscribe shapes — uncomment/adjust the one engineering provides
SUBSCRIBE_TEMPLATES = {
    "mark": {"method": "subscribe", "params": {"channel": "markPrice", "symbol": "{symbol}"}},
    "ltp": {"method": "subscribe", "params": {"channel": "ltp", "symbol": "{symbol}"}},
    "price": {"method": "subscribe", "params": {"channel": "price", "symbol": "{symbol}"}},
}


def build_subscribe(channel: str, symbol: str) -> str:
    template = SUBSCRIBE_TEMPLATES.get(channel, SUBSCRIBE_TEMPLATES["price"])
    payload = json.loads(json.dumps(template).replace("{symbol}", symbol))
    return json.dumps(payload)


async def run_test(
    ws_url: str,
    symbol: str,
    channel: str,
    duration: int,
    out_path: Path | None,
) -> int:
    messages: list[dict] = []
    print(f"Connecting to {ws_url}")
    print(f"Symbol: {symbol} | Channel template: {channel} | Duration: {duration}s")
    print("---")

    try:
        async with websockets.connect(
            ws_url,
            additional_headers={"X-Authentication": os.environ.get("MUDREX_API_SECRET", "")}
            if os.environ.get("MUDREX_API_SECRET")
            else None,
            open_timeout=10,
        ) as ws:
            sub = build_subscribe(channel, symbol)
            print(f"Subscribe: {sub}")
            await ws.send(sub)

            deadline = time.monotonic() + duration
            while time.monotonic() < deadline:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=min(5, duration))
                except asyncio.TimeoutError:
                    print("(no message in 5s)")
                    continue

                ts = datetime.now(timezone.utc).isoformat()
                print(f"[{ts}] {raw[:500]}")
                try:
                    messages.append({"ts": ts, "raw": json.loads(raw)})
                except json.JSONDecodeError:
                    messages.append({"ts": ts, "raw_text": raw})

    except Exception as exc:
        print(f"WebSocket error: {exc}", file=sys.stderr)
        print(
            "\nIf URL/schema are wrong, update MUDREX_WS_URL and SUBSCRIBE_TEMPLATES "
            "in price_websocket_test.py once engineering shares the contract.",
            file=sys.stderr,
        )
        return 1

    print("---")
    print(f"Received {len(messages)} message(s)")

    if out_path:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            for row in messages:
                f.write(json.dumps(row) + "\n")
        print(f"Saved to {out_path}")

    return 0 if messages else 2


def main() -> int:
    parser = argparse.ArgumentParser(description="Mudrex price WebSocket test")
    parser.add_argument("--url", default=DEFAULT_WS_URL, help="WebSocket URL")
    parser.add_argument("--symbol", default=DEFAULT_SYMBOL, help="Trading symbol")
    parser.add_argument(
        "--channel",
        default="price",
        choices=sorted(SUBSCRIBE_TEMPLATES.keys()),
        help="Subscribe template key",
    )
    parser.add_argument("--duration", type=int, default=30, help="Listen duration (seconds)")
    parser.add_argument(
        "--out",
        default="testing/ws/price-ws-capture.jsonl",
        help="Output JSONL path (empty to skip)",
    )
    args = parser.parse_args()

    out = Path(args.out) if args.out else None
    return asyncio.run(run_test(args.url, args.symbol, args.channel, args.duration, out))


if __name__ == "__main__":
    raise SystemExit(main())
