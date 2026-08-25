#!/usr/bin/env python3
"""Automated regression tests for extract_layout.py / compare_layout.py.

Covers the tier-2 inheritance fixture plus the adversarial probes from the
2026-08-25 cross-review (connectors, missing chOff, flip capture, unknown
elements, group-inherited placeholders). Run from anywhere:

    python3 evals/run_extractor_evals.py

Exit 0 = all pass, 1 = failures.
"""
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILS = []


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ext = load("extract_layout", ROOT / "scripts" / "extract_layout.py")
mif = load("make_inheritance_fixture", ROOT / "evals" / "fixtures" / "make_inheritance_fixture.py")


def check(label, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + label + (f" — {detail}" if detail and not cond else ""))
    if not cond:
        FAILS.append(label)


def build_variant(tmp, name, slide_xml):
    orig = mif.SLIDE
    mif.SLIDE = slide_xml
    out = str(Path(tmp) / name)
    mif.build(out)
    mif.SLIDE = orig
    return out


A = mif.A
P = mif.P
R = mif.R
HDR = f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<p:sld {P} {R} {A}><p:cSld><p:spTree>' \
      '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'
FTR = "</p:spTree></p:cSld></p:sld>"

with tempfile.TemporaryDirectory() as tmp:
    # --- tier-2: inheritance + theme color + run props ---
    fx = build_variant(tmp, "base.pptx", mif.SLIDE)
    spec = ext.extract(fx)
    sh = spec["slides"][0]["shapes"][0]
    check("tier2: geometry inherited from layout", sh["geometry_from"] == "layout", str(sh))
    check("tier2: layout coords (1.0, 0.5, 11.0, 1.2)",
          abs(sh["x_in"] - 1.0) < 0.01 and abs(sh["y_in"] - 0.5) < 0.01
          and abs(sh["w_in"] - 11.0) < 0.01 and abs(sh["h_in"] - 1.2) < 0.01, str(sh))
    fr = sh["text"]["first_run"]
    check("tier2: schemeClr accent1 -> FF5733", fr["color"] == "FF5733", str(fr))
    check("tier2: run props (32pt bold Noto Sans JP)",
          fr["size_pt"] == 32.0 and fr["bold"] and fr["font"] == "Noto Sans JP", str(fr))

    # --- probe: theme font fallback when run has no <a:latin> ---
    slide = HDR + ('<p:sp><p:nvSpPr><p:cNvPr id="2" name="T"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>'
                   '<p:spPr/><p:txBody><a:bodyPr/><a:p><a:r><a:rPr lang="ja-JP" sz="2000"/>'
                   "<a:t>no explicit font</a:t></a:r></a:p></p:txBody></p:sp>") + FTR
    spec = ext.extract(build_variant(tmp, "nofont.pptx", slide))
    fr = spec["slides"][0]["shapes"][0]["text"]["first_run"]
    check("probe: theme font inherited when run lacks latin",
          fr["font"] == "Noto Sans JP" and fr["font_from"] == "theme", str(fr))
    check("probe: fonts_used non-empty via theme", "Noto Sans JP" in spec["fonts_used"], str(spec["fonts_used"]))

    # --- probe: connector extracted ---
    slide = HDR + ('<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="3" name="Line 1"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>'
                   '<p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="1828800" cy="0"/></a:xfrm>'
                   '<a:prstGeom prst="line"/><a:ln w="25400"><a:solidFill><a:srgbClr val="112233"/></a:solidFill></a:ln>'
                   "</p:spPr></p:cxnSp>") + FTR
    spec = ext.extract(build_variant(tmp, "cxn.pptx", slide))
    shp = spec["slides"][0]["shapes"]
    check("probe: cxnSp captured as connector",
          len(shp) == 1 and shp[0]["kind"] == "connector" and shp[0]["line"]["color"] == "112233", str(shp))

    # --- probe: flipH/flipV captured ---
    slide = HDR + ('<p:sp><p:nvSpPr><p:cNvPr id="4" name="F"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
                   '<p:spPr><a:xfrm rot="2700000" flipH="1" flipV="1"><a:off x="0" y="0"/>'
                   '<a:ext cx="914400" cy="914400"/></a:xfrm><a:prstGeom prst="rect"/></p:spPr></p:sp>') + FTR
    spec = ext.extract(build_variant(tmp, "flip.pptx", slide))
    shp = spec["slides"][0]["shapes"][0]
    check("probe: flip + rot captured",
          shp.get("flip_h") is True and shp.get("flip_v") is True and shp["rot_deg"] == 45.0, str(shp))

    # --- probe: group without chOff/chExt -> no crash, warning ---
    slide = HDR + ('<p:grpSp><p:nvGrpSpPr><p:cNvPr id="5" name="G"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
                   '<p:grpSpPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="1828800" cy="1828800"/></a:xfrm></p:grpSpPr>'
                   '<p:sp><p:nvSpPr><p:cNvPr id="6" name="C"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
                   '<p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="914400" cy="914400"/></a:xfrm></p:spPr></p:sp>'
                   "</p:grpSp>") + FTR
    spec = ext.extract(build_variant(tmp, "grp.pptx", slide))
    sl = spec["slides"][0]
    check("probe: missing chOff no crash + warning",
          any("chOff" in w for w in sl["warnings"]) and sl["shape_count"] == 1, str(sl["warnings"]))

    # --- probe: unknown element warned ---
    slide = HDR + "<p:contentPart/>" + FTR
    spec = ext.extract(build_variant(tmp, "unk.pptx", slide))
    sl = spec["slides"][0]
    check("probe: unhandled element warned + confidence degraded",
          any("unhandled element" in w for w in sl["warnings"]) and sl["confidence"] == "measured-with-warnings",
          str(sl["warnings"]))

    # --- probe: group-inherited placeholder — slide-space geometry kept, warning ---
    slide = HDR + ('<p:grpSp><p:nvGrpSpPr><p:cNvPr id="7" name="G2"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
                   '<p:grpSpPr><a:xfrm><a:off x="4572000" y="2286000"/><a:ext cx="914400" cy="914400"/></a:xfrm>'
                   '<a:chOff x="0" y="0"/><a:chExt cx="1828800" cy="1828800"/></p:grpSpPr>'
                   '<p:sp><p:nvSpPr><p:cNvPr id="8" name="T2"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>'
                   '<p:spPr/><p:txBody><a:bodyPr/><a:p><a:r><a:t>x</a:t></a:r></a:p></p:txBody></p:sp>'
                   "</p:grpSp>") + FTR
    spec = ext.extract(build_variant(tmp, "grpph.pptx", slide))
    sh = spec["slides"][0]["shapes"][0]
    check("probe: inherited ph in group keeps slide-space coords (x=1.0) + warning",
          abs(sh["x_in"] - 1.0) < 0.01 and any("group transform NOT applied" in w for w in spec["slides"][0]["warnings"]),
          str(sh))

    # --- compare_layout smoke: fixture vs itself = 0 violations ---
    rc = subprocess.run([sys.executable, str(ROOT / "scripts" / "compare_layout.py"), fx, fx],
                        capture_output=True, text=True)
    check("compare_layout: self-compare exits 0", rc.returncode == 0, rc.stdout + rc.stderr)

    # --- schema conformance: extractor output validates against layout-spec.schema.json keys ---
    schema = json.loads((ROOT / "assets" / "layout-spec.schema.json").read_text())
    shape_props = set(schema["definitions"]["shape"]["properties"].keys())
    spec = ext.extract(fx)
    undeclared = {k for s in spec["slides"][0]["shapes"] for k in s.keys()} - shape_props
    check("schema: no undeclared shape keys", not undeclared, str(undeclared))

print()
if FAILS:
    print(f"FAIL: {len(FAILS)} test(s): {FAILS}")
    sys.exit(1)
print("ALL EXTRACTOR EVALS PASS")
