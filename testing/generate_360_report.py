#!/usr/bin/env python3
"""Generate Mark_Price_LTP_360_Test_Report.md from JSON results."""

from __future__ import annotations

import json
from pathlib import Path

REST_JSON = Path("testing/price-rest-360-results.json")
WS_JSON = Path("testing/price-ws-360-results.json")
OUTPUT = Path("Mark_Price_LTP_360_Test_Report.md")

KNOWN_ISSUES = [
    ("F1", "PM", "External 4 params without ohlcv returns o,h,l,v=0",
     "PM limits external users to `assets`, `aggregation`, `start_time`, `end_time`. Without `ohlcv`, candles return zeros except close at index 4."),
    ("F2", "DOC", "LIST_SUBSCRIPTIONS field names",
     "Doc says `ticker_assets`; live API returns `ticker_5s_assets` and `ticker_1s_assets`."),
    ("F3", "INFO", "Mark vs LTP closes differ",
     "Expected — mark is fair-value; LTP is last traded price."),
    ("F4", "BUG", "Single-asset mark-price path 404",
     "`GET /asset/btc/usdt/mark-price` returns 404; bulk `/assets/mark-price` works."),
    ("F5", "BUG", "Missing start_time returns 200",
     "Bulk klines without `start_time` returns 200 point-price shape instead of 400."),
    ("F6", "BUG/DOC", "WS idle timeout",
     "Doc says 40s inactivity close; may not fire within 55s on prod."),
    ("F7", "BUG", "Single-asset 1s klines 404",
     "`GET /asset/btc/usdt/klines?aggregation=1s&duration=300` returns asset not found."),
]


def load(path: Path) -> dict:
    if not path.exists():
        return {"results": [], "summary": {"total": 0, "pass": 0, "fail": 0}, "generated": "N/A"}
    return json.loads(path.read_text())


def main() -> None:
    rest = load(REST_JSON)
    ws = load(WS_JSON)
    all_results = []
    for r in rest.get("results", []):
        all_results.append({**r, "category": "REST"})
    for r in ws.get("results", []):
        all_results.append({**r, "category": "WS", "http_status": r.get("http_status", "—")})

    total_pass = sum(1 for r in all_results if r.get("pass"))
    total_fail = len(all_results) - total_pass
    flagged = []
    for r in all_results:
        for issue in r.get("issues", []):
            flagged.append({"test_id": r.get("test_id"), "issue": issue})

    lines = [
        "# Mark Price / LTP / WebSocket — 360° Test Report",
        "",
        f"**REST generated:** {rest.get('generated', 'N/A')}",
        f"**WS generated:** {ws.get('generated', 'N/A')}",
        "**Environment:** Production (`price.mudrex.com`)",
        "**Trading key:** Verified on `trade.mudrex.com` (INR futures funds)",
        "",
        "---",
        "",
        "## Summary",
        "",
        f"**Score: {total_pass} PASS, {total_fail} FAIL** (total {len(all_results)} tests)",
        "",
        "| # | ID | Cat | Test | Result | HTTP | Notes |",
        "|---|---|---|---|---|---|---|",
    ]

    for i, r in enumerate(all_results, 1):
        status = "PASS" if r.get("pass") else "**FAIL**"
        notes = (r.get("notes") or "")[:50].replace("|", "/")
        name = (r.get("name") or "")[:45].replace("|", "/")
        lines.append(f"| {i} | {r.get('test_id','')} | {r.get('category','')} | {name} | {status} | {r.get('http_status','—')} | {notes} |")

    lines.extend(["", "---", "", "## Issues Register", ""])
    for iid, sev, title, detail in KNOWN_ISSUES:
        lines.append(f"### {iid} [{sev}] {title}")
        lines.append("")
        lines.append(detail)
        lines.append("")

    if flagged:
        lines.extend(["### Confirmed in this test run", ""])
        seen = set()
        for f in flagged:
            key = f"{f['test_id']}:{f['issue']}"
            if key not in seen:
                lines.append(f"- **{f['test_id']}:** {f['issue']}")
                seen.add(key)
        lines.append("")

    fails = [r for r in all_results if not r.get("pass")]
    if fails:
        lines.extend(["---", "", "## Failed tests", ""])
        for r in fails:
            lines.append(f"### {r.get('test_id')} — {r.get('name')}")
            lines.append("")
            if r.get("url"):
                lines.append(f"**URL:** `{r.get('url')}`")
            lines.append(f"**HTTP:** {r.get('http_status', '—')}")
            lines.append("")
            for issue in r.get("issues", []):
                lines.append(f"- {issue}")
            lines.append("")

    # Key samples
    lines.extend(["---", "", "## Key request / response samples", ""])
    lines.append("### Bulk LTP klines (full params)")
    lines.append("")
    lines.append("```bash")
    lines.append('curl "https://price.mudrex.com/api/v1/assets/price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time=START&end_time=END&partial=true&type=linear"')
    lines.append("```")
    lines.append("")
    lines.append("Response shape: `data.asset_ticks[\"btc/usdt\"]` → `[time, o, h, l, c, volume]` (6 fields)")
    lines.append("")
    lines.append("### Bulk mark klines")
    lines.append("")
    lines.append("```bash")
    lines.append('curl "https://price.mudrex.com/api/v1/assets/mark-price?assets=btc/usdt&ohlcv=true&aggregation=1m&start_time=START&end_time=END&partial=true&type=linear"')
    lines.append("```")
    lines.append("")
    lines.append("Response shape: 5 fields — no volume")
    lines.append("")
    lines.append("### WS v2 linear subscribe")
    lines.append("")
    lines.append("```json")
    lines.append('{ "id": 1, "method": "SUBSCRIBE", "params": ["kline@1m@btcusdt", "markKline@1m@btcusdt", "ticker@5s"], "assets": ["btcusdt"] }')
    lines.append("```")
    lines.append("")

    lines.extend(["---", "", "## Recommendations", ""])
    lines.extend([
        "1. **PM:** Resolve F1 — document whether external users get full OHLCV or close-only ticks.",
        "2. **Docs:** Fix F2 `ticker_5s_assets` in LIST_SUBSCRIPTIONS response.",
        "3. **Engineering:** Fix F4 single-asset mark-price 404 or document bulk-only.",
        "4. **Engineering:** Fix F5 — validate required params return 400.",
        "5. **Engineering:** Clarify F6 idle timeout behavior on production.",
        "6. **Docs:** REST uses `btc/usdt`; WS uses `btcusdt`.",
        "7. **PM:** Confirm rate limit policy before external launch.",
        "",
        "---",
        "",
        "## Raw files",
        "",
        f"- `{REST_JSON}` — {rest.get('summary', {})}",
        f"- `{WS_JSON}` — {ws.get('summary', {})}",
        "- `testing/bulk-klines-test-results.md`",
        "- `testing/ws/price-v2-capture.jsonl`",
    ])

    OUTPUT.write_text("\n".join(lines) + "\n")
    print(f"Report: {total_pass}/{len(all_results)} pass → {OUTPUT}")


if __name__ == "__main__":
    main()
