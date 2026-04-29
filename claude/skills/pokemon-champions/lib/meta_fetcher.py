"""Phase 3: Freshness-critical layer (T3) fetcher with TTL cache and graceful degrade.

Caches metagame snapshots (Smogon stats, official Pokemon Champions sites) for 6 hours.
On fetch failure, returns the most recent stale cache marked with `stale: true` and
`stale_age_hours` so the SKILL prompt can flag it to the user.

Design:
    - URL allowlist hardcoded (no arbitrary URL fetching).
    - Cache key = sha256(url) -> ../cache/meta_<hash>.json
    - TTL configurable per-source.

Source-of-truth attribution:
    Smogon usage stats: https://www.smogon.com/stats/
    Official site (pending URL): https://pokemonchampions.pokemon.com/
    Yakkun (Japanese meta news): https://yakkun.com/sm/
"""

from __future__ import annotations

import hashlib
import json
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

CACHE_DIR = Path(__file__).resolve().parent.parent / "cache"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Allowlist with per-source TTL (seconds) and User-Agent
URL_ALLOWLIST: dict[str, dict] = {
    "https://www.smogon.com/stats/": {"ttl_sec": 6 * 3600, "label": "smogon_stats_index"},
    "https://yakkun.com/sm/": {"ttl_sec": 6 * 3600, "label": "yakkun_sm_index"},
    # PENDING: Official URL not yet announced. 6h TTL aligned with 鮮度命層 spec.
    # Until 200 OK confirmed, fetch will gracefully fall back to "未公開" stale marker.
    "https://pokemonchampions.pokemon.com/": {"ttl_sec": 6 * 3600, "label": "pokemonchampions_official_PENDING"},
}

USER_AGENT = "pokemon-champions-skill/0.1 (+https://github.com/anthropics/claude-code)"


@dataclass(frozen=True)
class FetchResult:
    """Immutable fetch result. `stale` flag indicates cache was used after fetch failure."""

    url: str
    ok: bool
    body: Optional[str]
    fetched_at: Optional[str]  # ISO 8601
    stale: bool
    stale_age_hours: Optional[float]
    source_label: str
    error: Optional[str]

    def to_dict(self) -> dict:
        return {
            "url": self.url,
            "ok": self.ok,
            "body": self.body,
            "fetched_at": self.fetched_at,
            "stale": self.stale,
            "stale_age_hours": self.stale_age_hours,
            "source_label": self.source_label,
            "error": self.error,
        }


def _cache_path(url: str) -> Path:
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
    return CACHE_DIR / f"meta_{digest}.json"


def _read_cache(url: str) -> Optional[dict]:
    path = _cache_path(url)
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def _write_cache(url: str, payload: dict) -> None:
    path = _cache_path(url)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=0), encoding="utf-8")


def _is_fresh(cache: dict, ttl_sec: int) -> bool:
    fetched_at_str = cache.get("fetched_at")
    if not fetched_at_str:
        return False
    try:
        fetched_at = datetime.fromisoformat(fetched_at_str.replace("Z", "+00:00"))
    except ValueError:
        return False
    age = (datetime.now(timezone.utc) - fetched_at).total_seconds()
    return age < ttl_sec


def _hours_since(iso_str: str) -> Optional[float]:
    try:
        t = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    except ValueError:
        return None
    return (datetime.now(timezone.utc) - t).total_seconds() / 3600.0


def _fetch_http(url: str, timeout: int = 10) -> tuple[bool, Optional[str], Optional[str]]:
    """Returns (ok, body, error). HTTP fetch via urllib (no external deps)."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body_bytes = resp.read()
            charset = resp.headers.get_content_charset() or "utf-8"
            body = body_bytes.decode(charset, errors="replace")
            return True, body, None
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        return False, None, f"{type(e).__name__}: {e}"
    except Exception as e:  # noqa: BLE001 - fetcher must never raise
        return False, None, f"{type(e).__name__}: {e}"


def fetch_meta(url: str, force: bool = False) -> FetchResult:
    """Fetch a meta-source URL with TTL cache and graceful stale-fallback.

    Args:
        url: Must be in URL_ALLOWLIST.
        force: Bypass cache if True (still writes cache on success).

    Returns:
        FetchResult. Always non-None; check `ok` and `stale`.
    """
    if url not in URL_ALLOWLIST:
        return FetchResult(
            url=url, ok=False, body=None, fetched_at=None, stale=False,
            stale_age_hours=None, source_label="unknown",
            error=f"URL not in allowlist (use one of: {list(URL_ALLOWLIST)})",
        )

    config = URL_ALLOWLIST[url]
    ttl = config["ttl_sec"]
    label = config["label"]

    cache = _read_cache(url)

    # Fresh cache hit
    if not force and cache and _is_fresh(cache, ttl):
        return FetchResult(
            url=url, ok=True, body=cache.get("body"),
            fetched_at=cache.get("fetched_at"), stale=False, stale_age_hours=0.0,
            source_label=label, error=None,
        )

    # Try live fetch
    ok, body, err = _fetch_http(url)
    if ok and body is not None:
        now_iso = datetime.now(timezone.utc).isoformat()
        _write_cache(url, {"url": url, "fetched_at": now_iso, "body": body, "label": label})
        return FetchResult(
            url=url, ok=True, body=body, fetched_at=now_iso, stale=False,
            stale_age_hours=0.0, source_label=label, error=None,
        )

    # Fetch failed -> graceful degrade to stale cache
    if cache and cache.get("body"):
        age_hours = _hours_since(cache.get("fetched_at", ""))
        return FetchResult(
            url=url, ok=True, body=cache["body"], fetched_at=cache.get("fetched_at"),
            stale=True, stale_age_hours=age_hours, source_label=label,
            error=f"Live fetch failed ({err}); returning stale cache.",
        )

    return FetchResult(
        url=url, ok=False, body=None, fetched_at=None, stale=False,
        stale_age_hours=None, source_label=label,
        error=f"Fetch failed and no cache available: {err}",
    )


def list_allowed_urls() -> list[dict]:
    return [{"url": url, **cfg} for url, cfg in URL_ALLOWLIST.items()]


if __name__ == "__main__":
    # Smoke check (no network call by default — set FETCH=1 to attempt)
    import sys

    print("Allowlist:")
    for entry in list_allowed_urls():
        print(f"  {entry['label']}: {entry['url']} (ttl={entry['ttl_sec']}s)")

    if os.environ.get("FETCH") == "1":
        url = sys.argv[1] if len(sys.argv) > 1 else "https://www.smogon.com/stats/"
        print(f"\nFetching: {url}")
        result = fetch_meta(url)
        d = result.to_dict()
        d["body"] = (d["body"][:200] + "...") if d["body"] else None
        print(json.dumps(d, ensure_ascii=False, indent=2))
