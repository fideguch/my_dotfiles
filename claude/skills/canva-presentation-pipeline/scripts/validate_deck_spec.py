#!/usr/bin/env python3
"""Validate a deck-spec.json against the deck-spec schema and archetype rules.

Stdlib only. Archetype rules mirror references/slide-archetypes.yaml; when
PyYAML is available the YAML file is read at runtime so the two cannot drift
(a failed YAML load falls back to the embedded defaults WITH a warning).

Exit codes: 0 = valid (warnings allowed), 1 = errors found,
2 = unreadable input or internal validator failure.
"""
import json
import re
import sys
from pathlib import Path

ARCHETYPES = {
    "cover":             {"required": ["title"], "max_bullets": 0},
    "section-divider":   {"required": ["title"], "max_bullets": 1},
    "executive-summary": {"required": ["title", "bullets"], "max_bullets": 4},
    "big-number":        {"required": ["title", "headline_value"], "max_bullets": 2},
    "two-column":        {"required": ["title", "columns"], "max_bullets": 4},
    "image-and-insight": {"required": ["title", "image", "insight"], "max_bullets": 2},
    "comparison":        {"required": ["title", "table"], "max_bullets": 0,
                          "min_table_rows": 2, "max_table_rows": 6, "max_table_cols": 5},
    "timeline":          {"required": ["title", "milestones"], "max_bullets": 0,
                          "min_milestones": 3, "max_milestones": 6},
    "process":           {"required": ["title", "steps"], "max_bullets": 0,
                          "min_steps": 3, "max_steps": 5},
    "evidence-chart":    {"required": ["title", "chart", "claim"], "max_bullets": 2,
                          "charts": True},
    "case-study":        {"required": ["title", "bullets"], "max_bullets": 4},
    "recommendation":    {"required": ["title", "bullets"], "max_bullets": 4},
    "closing":           {"required": ["title"], "max_bullets": 3},
}
ALLOWED_CHART_RENDER = {"png", "svg"}
ALLOWED_ASPECT_RATIOS = {"16:9"}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MAX_CONSECUTIVE_SAME = 2


def load_archetypes_from_yaml(warnings):
    """Prefer the YAML reference when PyYAML exists, so rules never drift."""
    try:
        import yaml  # type: ignore
    except ImportError:
        return None
    path = Path(__file__).resolve().parent.parent / "references" / "slide-archetypes.yaml"
    if not path.exists():
        return None
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        out = {}
        for name, spec in (data.get("archetypes") or {}).items():
            out[name] = {
                "required": spec.get("required_fields", ["title"]),
                "max_bullets": spec.get("max_bullets", 0),
                "min_table_rows": spec.get("min_table_rows"),
                "max_table_rows": spec.get("max_table_rows"),
                "max_table_cols": spec.get("max_table_cols"),
                "min_milestones": spec.get("min_milestones"),
                "max_milestones": spec.get("max_milestones"),
                "min_steps": spec.get("min_steps"),
                "max_steps": spec.get("max_steps"),
                "charts": spec.get("charts", False),
            }
        return out or None
    except Exception as exc:  # noqa: BLE001 — fall back, but never silently
        warnings.append(f"slide-archetypes.yaml unreadable ({exc}); using embedded fallback rules")
        return None


def str_list(value):
    """Return (list_of_strings, error_or_None) for a field that must be [str]."""
    if value is None:
        return [], None
    if not isinstance(value, list):
        return [], f"must be an array of strings, got {type(value).__name__}"
    bad = [i for i, x in enumerate(value) if not isinstance(x, str)]
    if bad:
        return [], f"items {bad} must be strings"
    return value, None


def validate_meta(spec, errors):
    meta = spec.get("meta")
    if not isinstance(meta, dict):
        errors.append("meta must be an object")
        return
    if not isinstance(meta.get("title"), str) or not meta.get("title"):
        errors.append("meta.title is required (non-empty string)")
    date = meta.get("date")
    if date is not None and (not isinstance(date, str) or not DATE_RE.match(date)):
        errors.append(f"meta.date must match YYYY-MM-DD, got {date!r}")
    ar = meta.get("aspect_ratio")
    if ar is not None and ar not in ALLOWED_ASPECT_RATIOS:
        errors.append(f"meta.aspect_ratio must be one of {sorted(ALLOWED_ASPECT_RATIOS)}, got {ar!r}")


def validate_slide(slide, idx, rules, errors):
    label = f"slide[{idx}] (id={slide.get('id', '?')})"

    arch = slide.get("archetype")
    if arch not in rules:
        errors.append(f"{label}: unknown archetype {arch!r}")
        return
    rule = rules[arch]

    for field in rule.get("required", []):
        present = bool(slide.get(field))
        if field == "claim" and not present:
            # evidence-chart: claim may live at slide level or inside chart
            chart = slide.get("chart")
            present = isinstance(chart, dict) and bool(chart.get("claim"))
        if not present:
            errors.append(f"{label}: archetype {arch!r} requires field {field!r}")

    bullets, err = str_list(slide.get("bullets"))
    if err:
        errors.append(f"{label}: bullets {err}")
    max_b = rule.get("max_bullets", 0)
    if len(bullets) > max_b:
        errors.append(f"{label}: {len(bullets)} bullets > max {max_b} for {arch!r}")

    cols = slide.get("columns")
    if cols is not None:
        if not isinstance(cols, list) or len(cols) != 2:
            errors.append(f"{label}: columns must be an array of exactly 2 objects")
        else:
            for c_i, col in enumerate(cols):
                if not isinstance(col, dict):
                    errors.append(f"{label}: column[{c_i}] must be an object")
                    continue
                if not isinstance(col.get("heading"), str) or not col.get("heading"):
                    errors.append(f"{label}: column[{c_i}].heading is required")
                col_bullets, err = str_list(col.get("bullets"))
                if err:
                    errors.append(f"{label}: column[{c_i}].bullets {err}")
                elif len(col_bullets) > rule.get("max_bullets", 4):
                    errors.append(f"{label}: column[{c_i}] has {len(col_bullets)} bullets "
                                  f"> max {rule.get('max_bullets', 4)}")

    table = slide.get("table")
    if table is not None:
        if not isinstance(table, dict):
            errors.append(f"{label}: table must be an object with headers and rows")
        else:
            headers, err = str_list(table.get("headers"))
            if err:
                errors.append(f"{label}: table.headers {err}")
            rows = table.get("rows")
            rows = rows if isinstance(rows, list) else []
            if rule.get("min_table_rows") and len(rows) < rule["min_table_rows"]:
                errors.append(f"{label}: {len(rows)} table rows < min {rule['min_table_rows']}")
            if rule.get("max_table_rows") and len(rows) > rule["max_table_rows"]:
                errors.append(f"{label}: {len(rows)} table rows > max {rule['max_table_rows']}")
            if rule.get("max_table_cols") and len(headers) > rule["max_table_cols"]:
                errors.append(f"{label}: {len(headers)} table cols > max {rule['max_table_cols']}")
            for r_i, row in enumerate(rows):
                cells, err = str_list(row)
                if err:
                    errors.append(f"{label}: table.rows[{r_i}] {err}")
                elif len(cells) != len(headers):
                    errors.append(f"{label}: row[{r_i}] has {len(cells)} cells, headers have {len(headers)}")

    milestones = slide.get("milestones")
    if milestones is not None:
        if not isinstance(milestones, list):
            errors.append(f"{label}: milestones must be an array of objects")
        else:
            for m_i, ms in enumerate(milestones):
                if not isinstance(ms, dict) or not ms.get("date") or not ms.get("label"):
                    errors.append(f"{label}: milestones[{m_i}] needs date and label")
            if rule.get("min_milestones") and len(milestones) < rule["min_milestones"]:
                errors.append(f"{label}: {len(milestones)} milestones < min {rule['min_milestones']}")
            if rule.get("max_milestones") and len(milestones) > rule["max_milestones"]:
                errors.append(f"{label}: {len(milestones)} milestones > max {rule['max_milestones']}")

    steps, err = str_list(slide.get("steps"))
    if err:
        errors.append(f"{label}: steps {err}")
    elif slide.get("steps") is not None:
        if rule.get("min_steps") and len(steps) < rule["min_steps"]:
            errors.append(f"{label}: {len(steps)} steps < min {rule['min_steps']}")
        if rule.get("max_steps") and len(steps) > rule["max_steps"]:
            errors.append(f"{label}: {len(steps)} steps > max {rule['max_steps']}")

    chart = slide.get("chart")
    if chart is not None:
        if not rule.get("charts"):
            errors.append(f"{label}: archetype {arch!r} does not allow charts")
        elif not isinstance(chart, dict):
            errors.append(f"{label}: chart must be an object")
        elif chart.get("render") not in ALLOWED_CHART_RENDER:
            errors.append(f"{label}: chart.render must be png or svg "
                          "(native PPTX charts break Canva import)")


def validate(spec, clone_mode=False):
    errors, warnings = [], []
    if not isinstance(spec, dict):
        return ["deck-spec root must be a JSON object"], warnings
    rules = load_archetypes_from_yaml(warnings) or ARCHETYPES

    validate_meta(spec, errors)

    slides = spec.get("slides")
    if not isinstance(slides, list) or len(slides) < 2:
        errors.append("slides must be a list with at least 2 entries")
        return errors, warnings

    dict_slides = []
    seen_ids = set()
    for idx, slide in enumerate(slides):
        if not isinstance(slide, dict):
            errors.append(f"slide[{idx}]: must be an object, got {type(slide).__name__}")
            continue
        dict_slides.append(slide)
        sid = slide.get("id")
        if not isinstance(sid, int):
            errors.append(f"slide[{idx}]: id is required and must be an integer")
        elif sid in seen_ids:
            errors.append(f"slide[{idx}] (id={sid}): duplicate id")
        else:
            seen_ids.add(sid)
        if clone_mode:
            tid = slide.get("template_id")
            if not isinstance(tid, str) or not tid.strip():
                errors.append(f"slide[{idx}]: template_id is required in clone mode "
                              "(every slide must map to a reference template — QA #12)")
        if slide.get("archetype") is None and clone_mode:
            # clone mode: layout comes from the reference template, archetype optional
            if not slide.get("title"):
                errors.append(f"slide[{idx}]: title is required")
            continue
        validate_slide(slide, idx, rules, errors)

    if dict_slides and not clone_mode:
        if dict_slides[0].get("archetype") != "cover":
            errors.append("first slide must be archetype 'cover'")
        if dict_slides[-1].get("archetype") != "closing":
            errors.append("last slide must be archetype 'closing'")

    run_arch, run_len = None, 0
    for slide in (dict_slides if not clone_mode else []):
        arch = slide.get("archetype")
        run_len = run_len + 1 if arch == run_arch else 1
        run_arch = arch
        if run_len == MAX_CONSECUTIVE_SAME + 1:
            warnings.append(f">{MAX_CONSECUTIVE_SAME} consecutive '{arch}' slides — vary the layout (QA rubric #6)")

    return errors, warnings


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    clone_mode = "--clone-mode" in argv
    if len(args) != 1:
        print("usage: validate_deck_spec.py [--clone-mode] <deck-spec.json>", file=sys.stderr)
        return 2
    try:
        spec = json.loads(Path(args[0]).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot read deck-spec: {exc}", file=sys.stderr)
        return 2

    try:
        errors, warnings = validate(spec, clone_mode=clone_mode)
    except Exception as exc:  # noqa: BLE001 — contract: never show a raw traceback
        print(f"ERROR: internal validator failure ({type(exc).__name__}: {exc}) — "
              "this is a validator bug, not a spec problem; report it", file=sys.stderr)
        return 2

    for w in warnings:
        print(f"WARN: {w}")
    for e in errors:
        print(f"ERROR: {e}")
    n = len(spec.get("slides") or []) if isinstance(spec, dict) else 0
    if errors:
        print(f"\nFAIL: {len(errors)} error(s), {len(warnings)} warning(s) across {n} slides")
        return 1
    print(f"OK: {n} slides valid ({len(warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
