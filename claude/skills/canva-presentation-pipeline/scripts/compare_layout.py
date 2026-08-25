#!/usr/bin/env python3
"""QA condition #11: geometry/style diff between a generated deck and its
reference. Compares layout only — text content (chars/paragraphs) is ignored
by design; content is SUPPOSED to differ.

Inputs are PPTX files or layout-spec JSONs (from extract_layout.py).
Slide mapping defaults to 1:1 by index; pass --map for allocation manifests
(e.g. --map "1:1,2:3,3:3" = generated slide 2 and 3 both clone reference
slide 3). Derived-template slides (congruent duplication) will report the
duplicated rows as 'added' — review those against the derivation rule and
whitelist deliberately via --allow-added.

Exit codes: 0 = within tolerance, 1 = violations, 2 = unreadable input.
"""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

PT_PER_IN = 72.0


def load_spec(path):
    p = Path(path)
    if p.suffix.lower() == ".json":
        return json.loads(p.read_text())
    spec_dir = Path(__file__).resolve().parent
    mod_spec = importlib.util.spec_from_file_location("extract_layout", spec_dir / "extract_layout.py")
    mod = importlib.util.module_from_spec(mod_spec)
    mod_spec.loader.exec_module(mod)
    return mod.extract(str(p))


def shape_sig(s):
    return (s["kind"], s.get("name") or "", (s.get("placeholder") or {}).get("type", ""))


def center(s):
    return (s["x_in"] + s["w_in"] / 2, s["y_in"] + s["h_in"] / 2)


def match_shapes(ref_shapes, gen_shapes):
    """Match by (kind,name,ph) first, then nearest center among same kind."""
    ref_left = list(range(len(ref_shapes)))
    gen_left = list(range(len(gen_shapes)))
    pairs = []
    ref_by_sig = {}
    for i in ref_left:
        ref_by_sig.setdefault(shape_sig(ref_shapes[i]), []).append(i)
    for j in list(gen_left):
        sig = shape_sig(gen_shapes[j])
        if ref_by_sig.get(sig):
            i = ref_by_sig[sig].pop(0)
            pairs.append((i, j))
            ref_left.remove(i)
            gen_left.remove(j)
    for j in list(gen_left):
        gk = gen_shapes[j]["kind"]
        cands = [i for i in ref_left if ref_shapes[i]["kind"] == gk]
        if not cands:
            continue
        gc = center(gen_shapes[j])
        best = min(cands, key=lambda i: (center(ref_shapes[i])[0] - gc[0]) ** 2 + (center(ref_shapes[i])[1] - gc[1]) ** 2)
        pairs.append((best, j))
        ref_left.remove(best)
        gen_left.remove(j)
    return pairs, ref_left, gen_left


STYLE_KEYS = ["preset", "fill"]
TEXT_STYLE_KEYS = ["size_pt", "font", "font_ea", "bold", "color"]


def compare_pair(r, g, tol_pt):
    d = {k: round((g[f"{k}_in"] - r[f"{k}_in"]) * PT_PER_IN, 2) for k in ("x", "y", "w", "h")}
    over = any(abs(v) > tol_pt for v in d.values())
    style = []
    for k in STYLE_KEYS:
        if (r.get(k) or None) != (g.get(k) or None):
            style.append(f"{k}: {r.get(k)} -> {g.get(k)}")
    rt, gt = r.get("text") or {}, g.get("text") or {}
    rf, gf = rt.get("first_run") or {}, gt.get("first_run") or {}
    for k in TEXT_STYLE_KEYS:
        if rf and gf and (rf.get(k) or None) != (gf.get(k) or None):
            style.append(f"text.{k}: {rf.get(k)} -> {gf.get(k)}")
    ri, gi = r.get("image") or {}, g.get("image") or {}
    if ri and gi and ri.get("srcRect_pct") != gi.get("srcRect_pct"):
        style.append(f"image.srcRect: {ri.get('srcRect_pct')} -> {gi.get('srcRect_pct')}")
    return {"ref": r.get("name"), "gen": g.get("name"), "kind": g["kind"],
            "delta_pt": d, "over_tolerance": over, "style_diffs": style}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("reference", help="reference .pptx or layout-spec .json")
    ap.add_argument("generated", help="generated .pptx or layout-spec .json")
    ap.add_argument("--map", default=None,
                    help="gen:ref slide index pairs, e.g. '1:1,2:3,3:3' (1-based). Default 1:1 by index")
    ap.add_argument("--tol-pt", type=float, default=2.0)
    ap.add_argument("--allow-added", default="",
                    help="comma-separated gen shape names allowed as additions (derived-template rows)")
    ap.add_argument("--json", dest="json_out", default=None)
    args = ap.parse_args()

    try:
        ref, gen = load_spec(args.reference), load_spec(args.generated)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2

    if args.map:
        mapping = []
        for pair in args.map.split(","):
            gs, rs = pair.split(":")
            mapping.append((int(gs), int(rs)))
    else:
        n = min(ref["slide_count"], gen["slide_count"])
        mapping = [(i, i) for i in range(1, n + 1)]
        if ref["slide_count"] != gen["slide_count"]:
            print(f"NOTE: slide counts differ (ref={ref['slide_count']} gen={gen['slide_count']}); "
                  "pass --map with the allocation manifest", file=sys.stderr)

    allow_added = {s.strip() for s in args.allow_added.split(",") if s.strip()}
    report, violations = [], 0
    for gidx, ridx in mapping:
        rs = ref["slides"][ridx - 1]["shapes"]
        gs = gen["slides"][gidx - 1]["shapes"]
        pairs, missing_i, added_j = match_shapes(rs, gs)
        entries = [compare_pair(rs[i], gs[j], args.tol_pt) for i, j in pairs]
        missing = [{"name": rs[i].get("name"), "kind": rs[i]["kind"]} for i in missing_i]
        added_all = [{"name": gs[j].get("name"), "kind": gs[j]["kind"]} for j in added_j]
        added = [a for a in added_all if (a["name"] or "") not in allow_added]
        allowed = [a for a in added_all if (a["name"] or "") in allow_added]
        n_over = sum(1 for e in entries if e["over_tolerance"])
        violations += n_over + len(missing) + len(added)
        report.append({"gen_slide": gidx, "ref_slide": ridx, "matched": len(entries),
                       "over_tolerance": n_over, "missing": missing, "added": added,
                       "allowed_additions": allowed,
                       "diffs": [e for e in entries if e["over_tolerance"] or e["style_diffs"]]})
        status = "OK " if not (n_over or missing or added) else "FAIL"
        print(f"{status} gen {gidx:>2} vs ref {ridx:>2}: matched={len(entries)} "
              f"over_tol={n_over} missing={len(missing)} added={len(added)}"
              + (f" allowed_added={len(allowed)}" if allowed else ""))

    if args.json_out:
        Path(args.json_out).write_text(json.dumps(
            {"tolerance_pt": args.tol_pt, "violations": violations, "slides": report},
            ensure_ascii=False, indent=1))
    if violations:
        print(f"\nFAIL: {violations} violation(s) beyond ±{args.tol_pt}pt — see report")
        return 1
    print(f"\nOK: all mapped slides within ±{args.tol_pt}pt of the reference layout")
    return 0


if __name__ == "__main__":
    sys.exit(main())
