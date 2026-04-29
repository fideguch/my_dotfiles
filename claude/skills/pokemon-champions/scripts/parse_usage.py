"""Parse Smogon usage stats text -> structured JSON.

Used for offline preprocessing of stats; complements the on-the-fly fetcher.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

UA = "pokemon-champions-skill/0.1"

ROW_RE = re.compile(
    r"\|\s+(\d+)\s+\|\s+([A-Za-z0-9'.: \-]+?)\s+\|\s+([\d.]+)%\s+\|\s+(\d+)\s+\|\s+([\d.]+)%\s+\|\s+(\d+)\s+\|\s+([\d.]+)%\s+\|"
)
TOTAL_RE = re.compile(r"^Total battles:\s+(\d+)")
WEIGHT_RE = re.compile(r"^Avg\. weight/team:\s+([\d.]+)")


def parse_usage_text(text: str) -> dict:
    rows: list[dict] = []
    total_battles = 0
    avg_weight = 0.0
    for line in text.splitlines():
        m_total = TOTAL_RE.match(line)
        if m_total:
            total_battles = int(m_total.group(1))
            continue
        m_weight = WEIGHT_RE.match(line)
        if m_weight:
            avg_weight = float(m_weight.group(1))
            continue
        m_row = ROW_RE.match(line)
        if m_row:
            rows.append({
                "rank": int(m_row.group(1)),
                "name": m_row.group(2).strip(),
                "usage_percent": float(m_row.group(3)),
                "raw": int(m_row.group(4)),
                "raw_percent": float(m_row.group(5)),
                "real": int(m_row.group(6)),
                "real_percent": float(m_row.group(7)),
            })
    return {
        "total_battles": total_battles,
        "avg_weight_per_team": avg_weight,
        "pokemon": rows,
    }


def fetch(url: str) -> str:
    req = Request(url, headers={"User-Agent": UA})
    with urlopen(req, timeout=15) as r:
        return r.read().decode("utf-8", errors="replace")


def main():
    if len(sys.argv) < 4:
        print("Usage: parse_usage.py <year-month> <format> <weight>", file=sys.stderr)
        print("  e.g. parse_usage.py 2026-03 gen9ou 1500", file=sys.stderr)
        sys.exit(2)
    ym, fmt, weight = sys.argv[1], sys.argv[2], sys.argv[3]
    url = f"https://www.smogon.com/stats/{ym}/{fmt}-{weight}.txt"
    print(f"Fetching {url}...")
    text = fetch(url)
    parsed = parse_usage_text(text)
    out_path = Path(__file__).resolve().parent.parent / "data" / "stats" / f"{fmt}-{weight}_{ym}.json"
    out_path.write_text(json.dumps({
        "source_url": url,
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "format": fmt,
        "weight": int(weight),
        "year_month": ym,
        **parsed,
    }, ensure_ascii=False, indent=0), encoding="utf-8")
    print(f"Wrote {out_path} ({len(parsed['pokemon'])} pokemon, total_battles={parsed['total_battles']})")


if __name__ == "__main__":
    main()
