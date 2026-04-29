"""Phase 4: Lazy-loaded data lookup with JP/EN/partial-match resolution.

Loaders cache data on first access. Resolvers normalize input (Japanese,
English, partial fuzzy) to internal Showdown IDs (e.g. "garchomp", "earthquake").

Usage:
    from lib.lookup import resolve_pokemon, get_pokedex_entry, resolve_move
    pid = resolve_pokemon("ガブリアス")           # -> {"id": "garchomp", "match_type": "jp_exact"}
    entry = get_pokedex_entry(pid["id"])         # -> dict from data/pokedex.json
"""

from __future__ import annotations

import functools
import json
import re
from pathlib import Path
from typing import Any, Optional

DATA_DIR = Path(__file__).resolve().parent.parent / "data"


@functools.lru_cache(maxsize=1)
def _load(filename: str) -> dict[str, Any]:
    path = DATA_DIR / filename
    if not path.exists():
        raise FileNotFoundError(f"Data file missing: {path}. Run scripts/extract_data.ts first.")
    return json.loads(path.read_text(encoding="utf-8"))


def get_pokedex() -> dict[str, Any]:
    return _load("pokedex.json")


def get_moves() -> dict[str, Any]:
    return _load("moves.json")


def get_abilities() -> dict[str, Any]:
    return _load("abilities.json")


def get_items() -> dict[str, Any]:
    return _load("items.json")


def get_typechart() -> dict[str, Any]:
    return _load("typechart.json")


def get_natures() -> dict[str, Any]:
    return _load("natures.json")


@functools.lru_cache(maxsize=1)
def _ja_names() -> dict:
    return _load("ja_names.json")


def _showdown_id(query: str) -> str:
    return re.sub(r"[^a-z0-9]", "", query.lower())


def _resolve(category: str, query: str) -> dict[str, Any]:
    """Resolve a query string to a Showdown internal ID.

    category: "pokemon" | "moves" | "abilities" | "items" | "types"
    Returns: {"id": "...", "match_type": "exact" | "jp_exact" | "partial" | "none",
              "candidates": [...]}  (candidates only set when match_type=partial or none)
    """
    if not query or not query.strip():
        return {"id": None, "match_type": "none", "candidates": [], "input": query}

    ja = _ja_names()
    jp_to_id = ja[category]["jp_to_id"]
    by_id_jp = ja[category]["by_id"]

    # 1. JP exact match
    if query in jp_to_id:
        return {"id": jp_to_id[query], "match_type": "jp_exact", "candidates": [], "input": query}

    # 2. EN-direct via showdown ID conversion
    sid = _showdown_id(query)
    # Decide source dict for "exists" check
    source_dicts = {
        "pokemon": get_pokedex,
        "moves": get_moves,
        "abilities": get_abilities,
        "items": get_items,
    }
    if category in source_dicts and sid in source_dicts[category]():
        return {"id": sid, "match_type": "exact", "candidates": [], "input": query}

    # 3. Partial match against JP names (substring) and EN id (prefix)
    candidates: list[str] = []
    if category in ja:
        for jp, vid in jp_to_id.items():
            if query in jp:
                candidates.append(vid)
    if category in source_dicts:
        for k in source_dicts[category]().keys():
            if k.startswith(sid) and k not in candidates and len(candidates) < 10:
                candidates.append(k)

    if len(candidates) == 1:
        return {"id": candidates[0], "match_type": "partial", "candidates": candidates, "input": query}
    if candidates:
        return {"id": None, "match_type": "ambiguous", "candidates": candidates[:10], "input": query}
    return {"id": None, "match_type": "none", "candidates": [], "input": query}


def resolve_pokemon(query: str) -> dict[str, Any]:
    return _resolve("pokemon", query)


def resolve_move(query: str) -> dict[str, Any]:
    return _resolve("moves", query)


def resolve_ability(query: str) -> dict[str, Any]:
    return _resolve("abilities", query)


def resolve_item(query: str) -> dict[str, Any]:
    return _resolve("items", query)


def get_pokedex_entry(pid: str) -> Optional[dict]:
    return get_pokedex().get(pid)


def get_move(mid: str) -> Optional[dict]:
    return get_moves().get(mid)


def get_ability(aid: str) -> Optional[dict]:
    return get_abilities().get(aid)


def get_item(iid: str) -> Optional[dict]:
    return get_items().get(iid)


def get_jp_name(category: str, sid: str) -> Optional[str]:
    """Reverse: showdown id -> JP name."""
    ja = _ja_names()
    return ja.get(category, {}).get("by_id", {}).get(sid)


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 3:
        print("Usage: lookup.py <category> <query>")
        print("  category: pokemon | moves | abilities | items")
        sys.exit(2)
    cat, q = sys.argv[1], " ".join(sys.argv[2:])
    fn = {"pokemon": resolve_pokemon, "moves": resolve_move,
          "abilities": resolve_ability, "items": resolve_item}[cat]
    result = fn(q)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result["id"] and cat == "pokemon":
        entry = get_pokedex_entry(result["id"])
        print("---")
        print(json.dumps({"name": entry["name"], "types": entry["types"], "baseStats": entry["baseStats"]},
                         ensure_ascii=False, indent=2))
