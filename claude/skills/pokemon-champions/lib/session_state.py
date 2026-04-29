"""Phase 4: Session state — persistent context across turns.

Stored at cache/session.json. Tracks:
    - team (user-input only; never auto-asked)
    - last_calc (most recent damage calc result)
    - last_topic (focus pokemon for `poke -n` invocation)
    - environment_snapshot (last fetched meta for diff later)
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

SESSION_PATH = Path(__file__).resolve().parent.parent / "cache" / "session.json"
SESSION_PATH.parent.mkdir(parents=True, exist_ok=True)


def _empty_state() -> dict:
    return {
        "version": 1,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "team": [],
        "last_calc": None,
        "last_topic": None,
        "environment_snapshot": None,
    }


def load() -> dict:
    if not SESSION_PATH.exists():
        return _empty_state()
    try:
        return json.loads(SESSION_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return _empty_state()


def save(state: dict) -> None:
    state = dict(state)  # immutable-style copy
    state["updated_at"] = datetime.now(timezone.utc).isoformat()
    SESSION_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def track_team(state: dict, team: list[dict]) -> dict:
    """Record team (user-provided only). Returns new state (immutable update)."""
    new = dict(state)
    new["team"] = team
    return new


def track_last_calc(state: dict, result: dict) -> dict:
    new = dict(state)
    new["last_calc"] = result
    return new


def track_last_topic(state: dict, pokemon_id: str) -> dict:
    new = dict(state)
    new["last_topic"] = pokemon_id
    return new


def get_focus_pokemon(state: dict) -> Optional[str]:
    """Return the central pokemon ID for `poke -n` invocation.

    Priority: last_topic > last_calc.attacker > team[0].
    """
    if state.get("last_topic"):
        return state["last_topic"]
    last_calc = state.get("last_calc") or {}
    if last_calc.get("attacker_name"):
        return last_calc["attacker_name"]
    team = state.get("team") or []
    if team and isinstance(team[0], dict) and team[0].get("id"):
        return team[0]["id"]
    return None


def reset() -> dict:
    """Clear session state (used on /pokechamp off)."""
    if SESSION_PATH.exists():
        SESSION_PATH.unlink()
    return _empty_state()


if __name__ == "__main__":
    s = load()
    print("Current session state:")
    print(json.dumps(s, ensure_ascii=False, indent=2))
