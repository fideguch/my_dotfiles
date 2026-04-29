"""Phase 4: Visualizers — Markdown tables + ASCII bars + matrices.

All renderers are pure functions returning markdown strings.
"""

from __future__ import annotations

from typing import Iterable, Optional


def render_damage_table(
    calc_result: dict,
    attacker_name: str,
    defender_name: str,
    attacker_jp: Optional[str] = None,
    defender_jp: Optional[str] = None,
) -> str:
    """Render damage calc as Markdown table + ASCII roll bar."""
    pmin = calc_result.get("percent_min", 0)
    pmax = calc_result.get("percent_max", 0)
    ko = calc_result.get("ko_chance", {}) or {}
    desc = calc_result.get("desc", "")
    damage = calc_result.get("damage", []) or []

    a = attacker_jp or attacker_name
    d = defender_jp or defender_name

    lines = []
    lines.append(f"## ダメ計: {a} → {d}")
    lines.append("")
    lines.append("| 指標 | 値 |")
    lines.append("|---|---|")
    lines.append(f"| 最小 | {pmin}% ({min(damage) if damage else 0}) |")
    lines.append(f"| 最大 | {pmax}% ({max(damage) if damage else 0}) |")
    if ko:
        lines.append(f"| 確定 | {ko.get('text', '-')} |")
    lines.append("")

    # ASCII bar (40 chars wide). Show pmin/pmax range over 0-200% scale.
    if pmin > 0 or pmax > 0:
        bar_max = 200.0
        bar_w = 40
        start = max(0, int(min(pmin, bar_max) / bar_max * bar_w))
        end = min(bar_w, int(min(pmax, bar_max) / bar_max * bar_w))
        bar = "[" + "·" * start + "█" * max(1, end - start) + " " * (bar_w - end) + "]"
        lines.append(f"```\n0%   50%   100%  150%  200%\n{bar}\n     {pmin}-{pmax}%\n```")

    if desc:
        lines.append("")
        lines.append(f"> {desc}")
    return "\n".join(lines)


# Type matchup table
TYPE_CHART_MULT_TO_SYMBOL = {
    4.0: "◎4倍",
    2.0: "○2倍",
    1.0: "  1倍",
    0.5: "△½",
    0.25: "△¼",
    0.0: "× 無",
}


def render_type_matchup(
    pokemon_types: list[str],
    typechart: dict,
    jp_type_names: Optional[dict[str, str]] = None,
) -> str:
    """Render an attack-type-vs-this-pokemon matchup grid.

    pokemon_types: e.g. ["Ground", "Fire"]
    typechart: data/typechart.json structure (mapping defender-type -> attacker-multipliers)
    jp_type_names: optional map TypeEN -> JP

    Returns markdown table.
    """
    # Effectiveness map: for each attacker type, multiplier vs the pokemon
    eff: dict[str, float] = {}
    for atk_type in typechart.keys():
        m = 1.0
        for def_type in pokemon_types:
            entry = typechart.get(def_type)
            if not entry:
                continue
            d = entry.get("damageTaken", {})
            code = d.get(atk_type)
            # Showdown encodes: 0 = neutral, 1 = weakness x2, 2 = resist x0.5, 3 = immune x0
            if code == 1:
                m *= 2.0
            elif code == 2:
                m *= 0.5
            elif code == 3:
                m *= 0.0
        eff[atk_type] = m

    # Bucket by multiplier
    buckets: dict[float, list[str]] = {4.0: [], 2.0: [], 1.0: [], 0.5: [], 0.25: [], 0.0: []}
    for t, mult in eff.items():
        if mult in buckets:
            buckets[mult].append(t)
        elif mult > 1.0:
            buckets[2.0 if mult == 2.0 else 4.0].append(t)
        elif mult < 1.0 and mult > 0:
            buckets[0.5 if mult == 0.5 else 0.25].append(t)
        elif mult == 0:
            buckets[0.0].append(t)

    def jp(t: str) -> str:
        return jp_type_names.get(t, t) if jp_type_names else t

    lines = []
    types_jp = " / ".join(jp(t) for t in pokemon_types)
    lines.append(f"## タイプ相性: {types_jp}")
    lines.append("")
    lines.append("| 倍率 | タイプ |")
    lines.append("|---|---|")
    for mult in [4.0, 2.0, 1.0, 0.5, 0.25, 0.0]:
        types = sorted(buckets[mult])
        if not types:
            continue
        lines.append(f"| {TYPE_CHART_MULT_TO_SYMBOL[mult]} | {', '.join(jp(t) for t in types)} |")
    return "\n".join(lines)


def render_role_matrix(
    self_team: list[str],
    opp_team: list[str],
    matchup_fn,
) -> str:
    """Render NxM matchup matrix as markdown table.

    matchup_fn(self_member, opp_member) -> str (e.g. '○', '×', '△') or short note.
    """
    lines = []
    lines.append("## 役割対象マトリクス")
    lines.append("")
    header = "| 自軍 \\ 相手 | " + " | ".join(opp_team) + " |"
    sep = "|---|" + "|".join(["---"] * len(opp_team)) + "|"
    lines.append(header)
    lines.append(sep)
    for s in self_team:
        cells = [matchup_fn(s, o) for o in opp_team]
        lines.append(f"| {s} | " + " | ".join(cells) + " |")
    return "\n".join(lines)


def render_cycle_flow(chain: list[str]) -> str:
    """Render an ASCII chain: A → B → C ↩."""
    if not chain:
        return "(empty cycle)"
    return "## サイクル\n```\n" + " → ".join(chain) + " ↩\n```"


def render_usage_top(
    usage_data: dict,
    n: int = 20,
    jp_name_fn=None,
) -> str:
    """Render top-N usage stats as markdown bar chart."""
    rows = usage_data.get("pokemon", [])[:n]
    if not rows:
        return "(no usage data)"
    max_pct = max(r["usage_percent"] for r in rows)
    bar_w = 30
    lines = []
    lines.append(f"## 使用率 TOP {n} (total_battles={usage_data.get('total_battles', '?')})")
    lines.append("")
    lines.append("```")
    for r in rows:
        name = r["name"]
        pct = r["usage_percent"]
        bar_len = int(pct / max_pct * bar_w)
        bar = "█" * bar_len + " " * (bar_w - bar_len)
        if jp_name_fn:
            jp = jp_name_fn(name) or name
            label = f"{r['rank']:3d}. {jp:<14s}"
        else:
            label = f"{r['rank']:3d}. {name:<20s}"
        lines.append(f"{label} {bar} {pct:5.2f}%")
    lines.append("```")
    return "\n".join(lines)
