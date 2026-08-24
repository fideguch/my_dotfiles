#!/usr/bin/env python3
"""Text-overflow linter for deck-spec.json.

Measures DISPLAY COLUMNS, not characters: East Asian Wide/Fullwidth chars
count as 2. Mixed JP/EN strings overflow slide boxes at equal char counts;
column width tracks what the rendered slide actually does.
(Approximation: ZWJ emoji sequences / combining marks are summed per
codepoint, which can over-count — acceptable for JP/EN business copy.)

Limits come from references/copy-limits.yaml when PyYAML is available; the
embedded defaults below are the fallback and are kept in sync with that file.
`bullets_per_slide_hard_max` applies to top-level bullets only — column
bullets are capped per column by the archetype rules in validate_deck_spec.py.

Exit codes: 0 = within limits, 1 = violations,
2 = unreadable input or internal failure.
"""
import json
import sys
import unicodedata
from pathlib import Path

LIMITS = {
    "title": 44,
    "subtitle": 60,
    "bullet": 64,
    "bullets_per_slide_hard_max": 5,
    "insight_or_claim": 80,
    "table_cell": 24,
    "headline_value": 12,
    "notes": 2000,
    "milestone_label": 48,
}


def load_limits_from_yaml(notices):
    """Prefer the YAML reference when PyYAML exists, so limits never drift."""
    try:
        import yaml  # type: ignore
    except ImportError:
        return None
    path = Path(__file__).resolve().parent.parent / "references" / "copy-limits.yaml"
    if not path.exists():
        return None
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        raw = data.get("limits") or {}
        out = dict(LIMITS)
        for key in ("title", "subtitle", "bullet", "insight_or_claim",
                    "table_cell", "headline_value", "notes", "milestone_label"):
            if isinstance(raw.get(key), dict) and "max_columns" in raw[key]:
                out[key] = raw[key]["max_columns"]
        if isinstance(raw.get("bullets_per_slide_hard_max"), int):
            out["bullets_per_slide_hard_max"] = raw["bullets_per_slide_hard_max"]
        return out
    except Exception as exc:  # noqa: BLE001 — fall back, but never silently
        notices.append(f"copy-limits.yaml unreadable ({exc}); using embedded fallback limits")
        return None


def display_width(text):
    return sum(2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
               for ch in text)


def check_slide(slide, idx, limits, violations):
    if not isinstance(slide, dict):
        violations.append(f"slide[{idx}]: must be an object, got {type(slide).__name__}")
        return
    label = f"slide[{idx}] (id={slide.get('id', '?')})"

    def over(name, text, limit):
        if not isinstance(text, str):
            violations.append(f"{label}: {name} must be a string, got {type(text).__name__}")
            return
        width = display_width(text)
        if width > limit:
            violations.append(f"{label}: {name} is {width} cols (max {limit}): {text[:40]}…")

    for key, limit_key in (("title", "title"), ("subtitle", "subtitle"),
                           ("headline_value", "headline_value"), ("notes", "notes"),
                           ("insight", "insight_or_claim"), ("claim", "insight_or_claim")):
        if slide.get(key) is not None:
            over(key, slide[key], limits[limit_key])
    chart = slide.get("chart")
    if isinstance(chart, dict) and chart.get("claim") is not None:
        over("chart.claim", chart["claim"], limits["insight_or_claim"])

    def as_str_items(value, name):
        if value is None:
            return []
        if not isinstance(value, list):
            violations.append(f"{label}: {name} must be an array, got {type(value).__name__}")
            return []
        return value

    top_bullets = as_str_items(slide.get("bullets"), "bullets")
    all_bullets = list(top_bullets)
    cols = slide.get("columns")
    if isinstance(cols, list):
        for col in cols:
            if isinstance(col, dict):
                all_bullets.extend(as_str_items(col.get("bullets"), "column bullets"))
    if len(top_bullets) > limits["bullets_per_slide_hard_max"]:
        violations.append(f"{label}: {len(top_bullets)} bullets "
                          f"(hard max {limits['bullets_per_slide_hard_max']})")
    for b_i, bullet in enumerate(all_bullets):
        over(f"bullet[{b_i}]", bullet, limits["bullet"])

    table = slide.get("table")
    if isinstance(table, dict):
        for cell in as_str_items(table.get("headers"), "table.headers"):
            over("table header", cell, limits["table_cell"])
        for r_i, row in enumerate(as_str_items(table.get("rows"), "table.rows")):
            for cell in (row if isinstance(row, list) else []):
                over(f"table row[{r_i}] cell", cell, limits["table_cell"])

    for step in as_str_items(slide.get("steps"), "steps"):
        over("step", step, limits["bullet"])
    for ms in as_str_items(slide.get("milestones"), "milestones"):
        if isinstance(ms, dict) and ms.get("label") is not None:
            over("milestone label", ms["label"], limits["milestone_label"])


def main(argv):
    if len(argv) != 2:
        print("usage: check_copy_limits.py <deck-spec.json>", file=sys.stderr)
        return 2
    try:
        spec = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot read deck-spec: {exc}", file=sys.stderr)
        return 2
    if not isinstance(spec, dict):
        print("ERROR: deck-spec root must be a JSON object", file=sys.stderr)
        return 2

    notices = []
    limits = load_limits_from_yaml(notices) or LIMITS
    for n in notices:
        print(f"WARN: {n}")

    violations = []
    try:
        slides = spec.get("slides")
        slides = slides if isinstance(slides, list) else []
        for idx, slide in enumerate(slides):
            check_slide(slide, idx, limits, violations)
    except Exception as exc:  # noqa: BLE001 — contract: never show a raw traceback
        print(f"ERROR: internal linter failure ({type(exc).__name__}: {exc}) — "
              "this is a linter bug, not a spec problem; report it", file=sys.stderr)
        return 2

    for v in violations:
        print(f"OVERFLOW: {v}")
    n = len(slides)
    if violations:
        print(f"\nFAIL: {len(violations)} issue(s) across {n} slides — "
              "trim copy (cut particles before nouns), don't shrink fonts")
        return 1
    print(f"OK: all text within display-width limits across {n} slides")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
