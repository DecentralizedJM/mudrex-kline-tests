#!/usr/bin/env bash
# Stream Mudrex Price WebSocket v2 — bulk multi-asset prices to terminal
#
# Usage:
#   bash "/Users/jm/Mudrex API Testing/testing/ws/stream_bulk_prices.sh"
#   ASSETS=all bash testing/ws/stream_bulk_prices.sh          # all ~581 futures
#   ASSETS=btcusdt,ethusdt bash testing/ws/stream_bulk_prices.sh
#   CONTINUOUS=1 ASSETS=btcusdt bash testing/ws/stream_bulk_prices.sh
#   JSON=1 ASSETS=all bash testing/ws/stream_bulk_prices.sh
#
# Environment:
#   ASSETS          Comma-separated WS symbols, or "all" (default: btcusdt,ethusdt)
#   MARKET          linear | spot (default: linear)
#   STREAMS         ticker | kline | markKline (comma-separated)
#   CONTINUOUS      1 = kline@1s mode (max 15 symbols — do NOT use with ASSETS=all)
#   KLINE_INTERVAL  1m | 1s
#   JSON            1 = raw JSON lines
#   COMPACT         1 = one summary line per push when many assets (default: 1 if >30 assets)
#   PING_EVERY      WS ping interval seconds (default: 20)
#   MUDREX_API_SECRET  Required to refresh symbol list when ASSETS=all (or use cache file)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

ASSETS="${ASSETS:-btcusdt,ethusdt}"
MARKET="${MARKET:-linear}"
CONTINUOUS="${CONTINUOUS:-0}"
JSON="${JSON:-0}"
PING_EVERY="${PING_EVERY:-20}"
SYMBOLS_CACHE="${SYMBOLS_CACHE:-testing/all-futures-symbols.json}"
MUDREX_API_SECRET="${MUDREX_API_SECRET:-}"

if [ "$CONTINUOUS" = "1" ]; then
  STREAMS="${STREAMS:-kline}"
  KLINE_INTERVAL="${KLINE_INTERVAL:-1s}"
else
  STREAMS="${STREAMS:-ticker}"
  KLINE_INTERVAL="${KLINE_INTERVAL:-1m}"
fi

# Resolve ASSETS=all → comma-separated ws symbols
if [ "$ASSETS" = "all" ]; then
  if [ -n "$MUDREX_API_SECRET" ]; then
    echo "Fetching all futures symbols from Trade API..."
    ASSETS="$(python3 -u << PY
import json, os, urllib.request
secret = os.environ["MUDREX_API_SECRET"]
base = "https://trade.mudrex.com/fapi/v1"
syms = []
offset = 0
while True:
    req = urllib.request.Request(
        f"{base}/futures?limit=100&offset={offset}&sort=popularity&order=asc",
        headers={"X-Authentication": secret, "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        batch = json.loads(r.read()).get("data") or []
    if not batch:
        break
    syms.extend(a["symbol"].lower() for a in batch)
    if len(batch) < 100:
        break
    offset += 100
cache = {"count": len(syms), "trade_symbols": [s.upper() for s in syms], "ws_symbols": syms}
with open("$SYMBOLS_CACHE", "w") as f:
    json.dump(cache, f, indent=2)
print(",".join(syms))
PY
)"
  elif [ -f "$SYMBOLS_CACHE" ]; then
    echo "Using cached symbols: $SYMBOLS_CACHE"
    ASSETS="$(python3 -c "import json; print(','.join(json.load(open('$SYMBOLS_CACHE'))['ws_symbols']))")"
  else
    echo "ERROR: ASSETS=all needs MUDREX_API_SECRET or existing $SYMBOLS_CACHE" >&2
    exit 1
  fi
  # All symbols: only ticker@5s works (581 klines would exceed 15 sub limit)
  if [ "$CONTINUOUS" = "1" ] || echo "$STREAMS" | grep -qE 'kline|mark'; then
    echo "WARN: ASSETS=all forces STREAMS=ticker (kline/markKline limited to 15 subs/connection)" >&2
    STREAMS="ticker"
    CONTINUOUS=0
  fi
fi

ASSET_COUNT="$(echo "$ASSETS" | tr ',' '\n' | grep -c . || true)"
if [ -z "${COMPACT:-}" ]; then
  if [ "$ASSET_COUNT" -gt 30 ]; then COMPACT=1; else COMPACT=0; fi
else
  COMPACT="${COMPACT}"
fi

case "$MARKET" in
  linear) WS_URL="${WS_URL:-wss://price.mudrex.com/api/v2/linear}" ;;
  spot)   WS_URL="${WS_URL:-wss://price.mudrex.com/api/v2/spot}" ;;
  *)
    echo "ERROR: MARKET must be linear or spot (got: $MARKET)" >&2
    exit 1
    ;;
esac

if ! python3 -c "import websockets" 2>/dev/null; then
  echo "Installing websockets..."
  pip3 install -q -r testing/ws/requirements.txt
fi

export WS_URL ASSETS STREAMS KLINE_INTERVAL JSON PING_EVERY MARKET COMPACT

echo "=== Mudrex bulk price stream ==="
echo "URL:     $WS_URL"
echo "Assets:  $ASSET_COUNT symbols"
echo "Streams: $STREAMS (kline interval: $KLINE_INTERVAL)"
echo "Format:  $([ "$JSON" = "1" ] && echo JSON || ([ "$COMPACT" = "1" ] && echo compact-table || echo full-table))"
echo "Ctrl+C to stop"
echo "---"

python3 -u << 'PYEOF'
import asyncio
import json
import os
import signal
import sys
from datetime import datetime, timezone

try:
    import websockets
except ImportError:
    sys.exit("websockets not installed — run: pip3 install -r testing/ws/requirements.txt")

WS_URL = os.environ["WS_URL"]
ASSETS = [a.strip().lower() for a in os.environ["ASSETS"].split(",") if a.strip()]
STREAMS = [s.strip().lower() for s in os.environ["STREAMS"].split(",") if s.strip()]
KLINE_INTERVAL = os.environ.get("KLINE_INTERVAL", "1m")
JSON_MODE = os.environ.get("JSON", "0") == "1"
COMPACT = os.environ.get("COMPACT", "0") == "1"
PING_EVERY = int(os.environ.get("PING_EVERY", "20"))
MARKET = os.environ.get("MARKET", "linear")
SUBSCRIBED = len(ASSETS)

if not ASSETS:
    sys.exit("ASSETS is empty")

if len(ASSETS) > 15 and any(s in ("kline", "markkline", "mark_kline") for s in STREAMS):
    print("ERROR: kline/markKline supports max 15 subscriptions per connection.", file=sys.stderr)
    print("       Use STREAMS=ticker for all symbols, or fewer ASSETS.", file=sys.stderr)
    sys.exit(1)


def build_params():
    params = []
    kline_count = 0
    for stream in STREAMS:
        if stream == "ticker":
            params.append("ticker@5s")
        elif stream == "kline":
            for sym in ASSETS:
                kline_count += 1
                if kline_count > 14:  # leave room if ticker also subscribed
                    print(f"WARN: capping kline subs at 14 (had {len(ASSETS)} assets)", file=sys.stderr)
                    break
                params.append(f"kline@{KLINE_INTERVAL}@{sym}")
        elif stream in ("markkline", "mark_kline"):
            if MARKET == "spot":
                print("WARN: markKline not on spot — skipped", file=sys.stderr)
                continue
            for sym in ASSETS:
                kline_count += 1
                if kline_count > 14:
                    break
                params.append(f"markKline@{KLINE_INTERVAL}@{sym}")
        else:
            print(f"WARN: unknown stream '{stream}'", file=sys.stderr)
    return params


def ts():
    return datetime.now(timezone.utc).strftime("%H:%M:%S")


def print_ticker_rows(rows: list):
    if COMPACT:
        parts = [f"{r.get('s','?')}={r.get('p','-')}" for r in rows[:8]]
        extra = len(rows) - 8
        tail = f" ... +{extra} more" if extra > 0 else ""
        print(f"[{ts()}] TICKER  {len(rows)}/{SUBSCRIBED} updates: {', '.join(parts)}{tail}")
    else:
        for row in rows:
            s = row.get("s", "?")
            p = row.get("p", "-")
            mp = row.get("mp", "-")
            mp_str = str(mp) if mp is not None else "-"
            print(f"[{ts()}] TICKER  {s:12}  LTP={p:<12}  mark={mp_str}")


def print_table(msg: dict):
    if msg.get("method") and msg.get("result"):
        print(f"[{ts()}] SUBSCRIBE ok — {SUBSCRIBED} assets, streams={msg.get('params', [])}")
        return
    if msg.get("error"):
        print(f"[{ts()}] ERROR {json.dumps(msg.get('error'))}")
        return

    stream = msg.get("stream", "")
    data = msg.get("data")

    if stream == "ticker@5s" and isinstance(data, list):
        print_ticker_rows(data)
        return

    if stream.startswith("kline@") and isinstance(data, dict):
        s = data.get("s", "?")
        o, h, l, c, v = data.get("o"), data.get("h"), data.get("l"), data.get("c"), data.get("v")
        print(f"[{ts()}] KLINE   {s:12}  c={c}  v={v}")
        return

    if stream.startswith("markKline@") and isinstance(data, dict):
        s = data.get("s", "?")
        c = data.get("c")
        print(f"[{ts()}] MARK    {s:12}  c={c}")
        return

    print(f"[{ts()}] {json.dumps(msg)}")


async def ping_loop(ws):
    while True:
        await asyncio.sleep(PING_EVERY)
        try:
            await ws.ping()
        except Exception:
            break


async def main():
    params = build_params()
    if not params:
        sys.exit("No streams to subscribe")

    assets_for_ticker = ASSETS if "ticker@5s" in params else None
    sub = {"id": 1, "method": "SUBSCRIBE", "params": params}
    if assets_for_ticker:
        sub["assets"] = assets_for_ticker

    stop = asyncio.Event()

    def _stop(*_):
        stop.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _stop)
        except NotImplementedError:
            pass

    print(f"[{ts()}] Connecting {WS_URL}")

    async with websockets.connect(WS_URL, open_timeout=30, ping_interval=None) as ws:
        await ws.send(json.dumps(sub))
        ping_task = asyncio.create_task(ping_loop(ws))

        try:
            while not stop.is_set():
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=1.0)
                except asyncio.TimeoutError:
                    continue
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    continue

                if JSON_MODE:
                    print(json.dumps({"ts": datetime.now(timezone.utc).isoformat(), "msg": msg}))
                else:
                    print_table(msg)
        finally:
            ping_task.cancel()
            try:
                await ping_task
            except asyncio.CancelledError:
                pass

    print(f"[{ts()}] Stopped.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nStopped.")

PYEOF
