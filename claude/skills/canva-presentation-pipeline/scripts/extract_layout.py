#!/usr/bin/env python3
"""Extract a machine-readable layout-spec from a PPTX.

Purpose (skill v2): layouts are cloned, never invented. This tool provides
the measured ground truth — for the PDF/image rebuild route it is the source
of coordinates; for the PPTX direct-edit route it powers QA condition #11
(template-match geometry diff, via compare_layout.py).

Resolves: placeholder inheritance (slide -> slideLayout -> slideMaster),
theme scheme colors (via the master's clrMap), theme major/minor fonts,
group transforms (nested, composed), image crops (srcRect), slide
backgrounds, connectors, AlternateContent fallbacks, and layout/master
decoration shapes (logos, footers) that render behind every slide.
Unhandled constructs are WARNED, never silently dropped; any warning
degrades `confidence`. Stdlib only.

Known limitations (documented, warned where detectable): color tint/shade/
alpha modifiers, clrMapOvr, full OOXML placeholder-matching rules, affine
composition for rotated/flipped nested groups (flip/rot are captured per
shape, not composed through groups).

Exit codes: 0 ok, 2 unreadable input or extractor failure.
"""
import argparse
import json
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "mc": "http://schemas.openxmlformats.org/markup-compatibility/2006",
}
EMU_PER_IN = 914400.0
HANDLED = {"sp", "pic", "graphicFrame", "grpSp", "cxnSp", "nvGrpSpPr", "grpSpPr", "AlternateContent"}


def q(tag):
    pfx, local = tag.split(":")
    return f"{{{NS[pfx]}}}{local}"


def parse_rels(z, part_path):
    p = Path(part_path)
    rels_path = str(p.parent / "_rels" / (p.name + ".rels"))
    out = {}
    if rels_path not in z.namelist():
        return out
    root = ET.fromstring(z.read(rels_path))
    for rel in root:
        rid, target = rel.get("Id"), rel.get("Target")
        if rel.get("TargetMode") == "External":
            out[rid] = target
            continue
        parts = list(p.parent.parts)
        for seg in Path(target).parts:
            if seg == "..":
                parts.pop()
            elif seg != ".":
                parts.append(seg)
        out[rid] = "/".join(parts)
    return out


def load_theme(z, theme_path):
    scheme, fonts = {}, {}
    if not theme_path or theme_path not in z.namelist():
        return scheme, fonts
    root = ET.fromstring(z.read(theme_path))
    clr = root.find(f"{q('a:themeElements')}/{q('a:clrScheme')}")
    if clr is not None:
        for child in clr:
            name = child.tag.split("}")[1]
            srgb, sysc = child.find(q("a:srgbClr")), child.find(q("a:sysClr"))
            if srgb is not None:
                scheme[name] = srgb.get("val")
            elif sysc is not None:
                scheme[name] = sysc.get("lastClr", "000000")
    fs = root.find(f"{q('a:themeElements')}/{q('a:fontScheme')}")
    if fs is not None:
        for kind, tag in (("major", "a:majorFont"), ("minor", "a:minorFont")):
            f = fs.find(q(tag))
            if f is not None:
                latin = f.find(q("a:latin"))
                ea = f.find(q("a:ea"))
                fonts[kind] = {"latin": latin.get("typeface") if latin is not None else None,
                               "ea": ea.get("typeface") if ea is not None else None}
    return scheme, fonts


def resolve_color(elem, theme, clr_map, warnings):
    if elem is None:
        return None
    srgb = elem.find(q("a:srgbClr"))
    if srgb is not None:
        return srgb.get("val")
    sch = elem.find(q("a:schemeClr"))
    if sch is not None:
        val = sch.get("val")
        if len(sch) > 0:
            warnings.append(f"color modifiers (tint/shade/alpha) on schemeClr {val} not resolved")
        mapped = clr_map.get(val, val)
        hexv = theme.get(mapped)
        if hexv is None:
            warnings.append(f"unresolved schemeClr {val}")
            return f"scheme:{val}"
        return hexv
    sysc = elem.find(q("a:sysClr"))
    if sysc is not None:
        return sysc.get("lastClr", "000000")
    return None


def get_xfrm(sp_pr):
    if sp_pr is None:
        return None
    xfrm = sp_pr.find(q("a:xfrm"))
    if xfrm is None:
        return None
    off, ext = xfrm.find(q("a:off")), xfrm.find(q("a:ext"))
    if off is None or ext is None:
        return None
    return {"x": int(off.get("x")), "y": int(off.get("y")),
            "cx": int(ext.get("cx")), "cy": int(ext.get("cy")),
            "rot": int(xfrm.get("rot", "0")),
            "flip_h": xfrm.get("flipH") == "1", "flip_v": xfrm.get("flipV") == "1"}


def ph_key(nv_pr):
    if nv_pr is None:
        return None
    ph = nv_pr.find(q("p:ph"))
    if ph is None:
        return None
    return (ph.get("type", "body"), ph.get("idx", "0"))


def index_placeholders(z, part, warnings):
    out = {}
    if not part or part not in z.namelist():
        return out
    root = ET.fromstring(z.read(part))
    for sp in root.iter(q("p:sp")):
        nv = sp.find(f"{q('p:nvSpPr')}/{q('p:nvPr')}")
        key = ph_key(nv)
        if key is None:
            continue
        xf = get_xfrm(sp.find(q("p:spPr")))
        if xf is not None:
            if key in out:
                warnings.append(f"duplicate placeholder {key} in {part} — later one wins")
            out[key] = xf
    return out


def text_info(sp, theme, clr_map, theme_fonts, ph, fonts_seen, warnings):
    tx = sp.find(q("p:txBody"))
    if tx is None:
        return None
    body_pr = tx.find(q("a:bodyPr"))
    paras = tx.findall(q("a:p"))
    chars, first = 0, None
    has_bullet = False
    theme_kind = "major" if ph and ph[0] in ("title", "ctrTitle") else "minor"
    tf = theme_fonts.get(theme_kind, {})
    for para in paras:
        ppr = para.find(q("a:pPr"))
        if ppr is not None and (ppr.find(q("a:buChar")) is not None or ppr.find(q("a:buAutoNum")) is not None):
            has_bullet = True
        for run in para.findall(q("a:r")):
            t = run.find(q("a:t"))
            text = t.text or "" if t is not None else ""
            chars += len(text)
            rpr = run.find(q("a:rPr"))
            latin = rpr.find(q("a:latin")).get("typeface") if rpr is not None and rpr.find(q("a:latin")) is not None else None
            ea = rpr.find(q("a:ea")).get("typeface") if rpr is not None and rpr.find(q("a:ea")) is not None else None
            for fname in (latin or tf.get("latin"), ea or tf.get("ea")):
                if fname:
                    fonts_seen.add(fname.replace("+mj-lt", tf.get("latin") or "").replace("+mn-lt", tf.get("latin") or "") or fname)
            if first is None and text.strip():
                first = {
                    "size_pt": int(rpr.get("sz")) / 100 if rpr is not None and rpr.get("sz") else None,
                    "bold": rpr is not None and rpr.get("b") == "1",
                    "color": resolve_color(rpr.find(q("a:solidFill")) if rpr is not None else None, theme, clr_map, warnings),
                    "font": latin or tf.get("latin"),
                    "font_ea": ea or tf.get("ea"),
                    "font_from": "run" if latin else ("theme" if tf.get("latin") else None),
                }
    p0 = paras[0].find(q("a:pPr")) if paras else None
    return {
        "first_run": first,
        "align": p0.get("algn") if p0 is not None else None,
        "anchor": body_pr.get("anchor") if body_pr is not None else None,
        "wrap": body_pr.get("wrap") if body_pr is not None else None,
        "autofit": ("normAutofit" if body_pr is not None and body_pr.find(q("a:normAutofit")) is not None
                    else "spAutoFit" if body_pr is not None and body_pr.find(q("a:spAutoFit")) is not None else None),
        "bullets": has_bullet,
        "paragraphs": len(paras),
        "chars": chars,
    }


def emu_box(xf, scale=None):
    x, y, cx, cy = xf["x"], xf["y"], xf["cx"], xf["cy"]
    if scale:
        gx, gy, sx, sy, chx, chy = scale
        x = gx + (x - chx) * sx
        y = gy + (y - chy) * sy
        cx, cy = cx * sx, cy * sy
    box = {"x_in": round(x / EMU_PER_IN, 3), "y_in": round(y / EMU_PER_IN, 3),
           "w_in": round(cx / EMU_PER_IN, 3), "h_in": round(cy / EMU_PER_IN, 3),
           "rot_deg": round(xf.get("rot", 0) / 60000, 1)}
    if xf.get("flip_h"):
        box["flip_h"] = True
    if xf.get("flip_v"):
        box["flip_v"] = True
    return box


def src_rect_pct(el, warnings):
    if el is None:
        return None
    vals = {k: int(el.get(k, "0")) / 1000 for k in ("l", "t", "r", "b")}
    for k, v in vals.items():
        if not (0 <= v <= 100):
            warnings.append(f"srcRect.{k}={v} outside 0-100% — suspicious crop")
    return vals


def walk_shapes(z, tree, ctx, scale=None, in_group=False, layer="slide"):
    theme, clr_map, theme_fonts, layout_ph, master_ph, rels, warnings, fonts_seen = ctx
    shapes = []
    for child in tree:
        local = child.tag.split("}")[1]
        if child.tag == q("p:sp"):
            nv = child.find(f"{q('p:nvSpPr')}/{q('p:nvPr')}")
            name_el = child.find(f"{q('p:nvSpPr')}/{q('p:cNvPr')}")
            key = ph_key(nv)
            sp_pr = child.find(q("p:spPr"))
            xf = get_xfrm(sp_pr)
            src = layer
            eff_scale = scale
            if xf is None and key is not None:
                if key in layout_ph:
                    xf, src = layout_ph[key], "layout"
                elif key in master_ph:
                    xf, src = master_ph[key], "master"
                if xf is not None and in_group:
                    warnings.append(f"placeholder {key} inside a group inherits slide-space geometry — group transform NOT applied")
                    eff_scale = None
            if xf is None:
                warnings.append(f"shape '{name_el.get('name') if name_el is not None else '?'}' has no resolvable geometry")
                continue
            geom = child.find(f"{q('p:spPr')}/{q('a:prstGeom')}")
            fill = resolve_color(sp_pr.find(q("a:solidFill")) if sp_pr is not None else None, theme, clr_map, warnings)
            ln = sp_pr.find(q("a:ln")) if sp_pr is not None else None
            shapes.append({
                "kind": "text" if child.find(q("p:txBody")) is not None else "shape",
                "name": name_el.get("name") if name_el is not None else None,
                "placeholder": {"type": key[0], "idx": key[1]} if key else None,
                "geometry_from": src, "layer": layer, "in_group": in_group,
                **emu_box(xf, eff_scale),
                "preset": geom.get("prst") if geom is not None else None,
                "fill": fill,
                "line": {"color": resolve_color(ln.find(q("a:solidFill")), theme, clr_map, warnings),
                         "w_pt": round(int(ln.get("w")) / 12700, 2) if ln.get("w") else None} if ln is not None else None,
                "text": text_info(child, theme, clr_map, theme_fonts, key, fonts_seen, warnings),
            })
        elif child.tag == q("p:cxnSp"):
            name_el = child.find(f"{q('p:nvCxnSpPr')}/{q('p:cNvPr')}")
            sp_pr = child.find(q("p:spPr"))
            xf = get_xfrm(sp_pr)
            if xf is None:
                warnings.append("connector without geometry")
                continue
            ln = sp_pr.find(q("a:ln")) if sp_pr is not None else None
            geom = sp_pr.find(q("a:prstGeom")) if sp_pr is not None else None
            shapes.append({
                "kind": "connector",
                "name": name_el.get("name") if name_el is not None else None,
                "geometry_from": layer, "layer": layer, "in_group": in_group,
                **emu_box(xf, scale),
                "preset": geom.get("prst") if geom is not None else None,
                "line": {"color": resolve_color(ln.find(q("a:solidFill")), theme, clr_map, warnings),
                         "w_pt": round(int(ln.get("w")) / 12700, 2) if ln.get("w") else None} if ln is not None else None,
            })
        elif child.tag == q("p:pic"):
            name_el = child.find(f"{q('p:nvPicPr')}/{q('p:cNvPr')}")
            xf = get_xfrm(child.find(q("p:spPr")))
            if xf is None:
                warnings.append("picture without geometry")
                continue
            blip = child.find(f"{q('p:blipFill')}/{q('a:blip')}")
            shapes.append({
                "kind": "image",
                "name": name_el.get("name") if name_el is not None else None,
                "geometry_from": layer, "layer": layer, "in_group": in_group,
                **emu_box(xf, scale),
                "image": {"target": rels.get(blip.get(q("r:embed"))) if blip is not None else None,
                          "srcRect_pct": src_rect_pct(child.find(f"{q('p:blipFill')}/{q('a:srcRect')}"), warnings)},
            })
        elif child.tag == q("p:graphicFrame"):
            xf_el = child.find(q("p:xfrm"))
            if xf_el is not None:
                off, ext = xf_el.find(q("a:off")), xf_el.find(q("a:ext"))
                xf = {"x": int(off.get("x")), "y": int(off.get("y")),
                      "cx": int(ext.get("cx")), "cy": int(ext.get("cy")), "rot": 0}
                has_table = child.find(f".//{q('a:tbl')}") is not None
                shapes.append({"kind": "table" if has_table else "graphicFrame",
                               "geometry_from": layer, "layer": layer, "in_group": in_group,
                               **emu_box(xf, scale)})
        elif child.tag == q("p:grpSp"):
            grp_pr = child.find(q("p:grpSpPr"))
            xfrm = grp_pr.find(q("a:xfrm")) if grp_pr is not None else None
            if xfrm is None:
                warnings.append("group without transform — children treated as untransformed")
                shapes.extend(walk_shapes(z, child, ctx, scale=scale, in_group=True, layer=layer))
                continue
            off, ext = xfrm.find(q("a:off")), xfrm.find(q("a:ext"))
            ch_off, ch_ext = xfrm.find(q("a:chOff")), xfrm.find(q("a:chExt"))
            gx = int(off.get("x")) if off is not None else 0
            gy = int(off.get("y")) if off is not None else 0
            cx = int(ext.get("cx")) if ext is not None else 0
            cy = int(ext.get("cy")) if ext is not None else 0
            if ch_off is None or ch_ext is None:
                warnings.append("group missing chOff/chExt — identity child mapping assumed")
                chx, chy, chcx, chcy = 0, 0, cx or 1, cy or 1
            else:
                chx, chy = int(ch_off.get("x")), int(ch_off.get("y"))
                chcx = int(ch_ext.get("cx")) or cx or 1
                chcy = int(ch_ext.get("cy")) or cy or 1
            if scale:  # compose with parent transform
                pgx, pgy, psx, psy, pchx, pchy = scale
                gx = pgx + (gx - pchx) * psx
                gy = pgy + (gy - pchy) * psy
                sub = (gx, gy, (cx * psx) / chcx, (cy * psy) / chcy, chx, chy)
            else:
                sub = (gx, gy, cx / chcx, cy / chcy, chx, chy)
            if xfrm.get("rot") or xfrm.get("flipH") == "1" or xfrm.get("flipV") == "1":
                warnings.append("group rot/flip not composed into child coordinates — verify visually")
            shapes.extend(walk_shapes(z, child, ctx, scale=sub, in_group=True, layer=layer))
        elif child.tag == q("mc:AlternateContent"):
            fb = child.find(q("mc:Fallback"))
            if fb is not None:
                shapes.extend(walk_shapes(z, fb, ctx, scale=scale, in_group=in_group, layer=layer))
                warnings.append("AlternateContent: extracted Fallback branch (SmartArt/chart rendered as fallback shapes)")
            else:
                warnings.append("AlternateContent without Fallback — content dropped")
        elif local in ("nvGrpSpPr", "grpSpPr"):
            continue
        else:
            warnings.append(f"unhandled element <{local}> — not extracted")
    return shapes


def extract_background(z, slide_root, layout_path, master_path, theme, clr_map, warnings):
    for part_root, src in ((slide_root, "slide"),):
        bg = part_root.find(f"{q('p:cSld')}/{q('p:bg')}")
        if bg is not None:
            pr = bg.find(q("p:bgPr"))
            if pr is not None:
                c = resolve_color(pr.find(q("a:solidFill")), theme, clr_map, warnings)
                return {"color": c, "from": src} if c else {"color": None, "from": src}
            if bg.find(q("p:bgRef")) is not None:
                warnings.append("background uses bgRef (theme fill style) — color not resolved")
                return {"color": None, "from": src}
    for part, src in ((layout_path, "layout"), (master_path, "master")):
        if not part or part not in z.namelist():
            continue
        root = ET.fromstring(z.read(part))
        bg = root.find(f"{q('p:cSld')}/{q('p:bg')}")
        if bg is not None:
            pr = bg.find(q("p:bgPr"))
            if pr is not None:
                c = resolve_color(pr.find(q("a:solidFill")), theme, clr_map, warnings)
                return {"color": c, "from": src}
            warnings.append(f"background bgRef on {src} — color not resolved")
            return {"color": None, "from": src}
    return None


def non_placeholder_shapes(z, part, ctx, layer):
    """Decoration shapes (no ph) defined on a layout/master — they render on every slide."""
    if not part or part not in z.namelist():
        return []
    root = ET.fromstring(z.read(part))
    tree = root.find(f"{q('p:cSld')}/{q('p:spTree')}")
    if tree is None:
        return []
    shapes = walk_shapes(z, tree, ctx, layer=layer)
    return [s for s in shapes if not s.get("placeholder")]


def extract(path):
    z = zipfile.ZipFile(path)
    pres = ET.fromstring(z.read("ppt/presentation.xml"))
    pres_rels = parse_rels(z, "ppt/presentation.xml")
    sld_sz = pres.find(q("p:sldSz"))
    size = {"w_in": round(int(sld_sz.get("cx")) / EMU_PER_IN, 3),
            "h_in": round(int(sld_sz.get("cy")) / EMU_PER_IN, 3)} if sld_sz is not None else None
    slide_paths = []
    lst = pres.find(q("p:sldIdLst"))
    if lst is not None:
        for sid in lst:
            slide_paths.append(pres_rels.get(sid.get(q("r:id"))))

    out_slides, fonts_seen = [], set()
    deco_cache = {}
    for idx, spath in enumerate(slide_paths, 1):
        warnings = []
        rels = parse_rels(z, spath)
        layout_path = next((t for t in rels.values() if t and "slideLayout" in t), None)
        layout_rels = parse_rels(z, layout_path) if layout_path else {}
        master_path = next((t for t in layout_rels.values() if t and "slideMaster" in t), None)
        master_rels = parse_rels(z, master_path) if master_path else {}
        theme_path = next((t for t in master_rels.values() if t and "theme" in t), None)
        theme, theme_fonts = load_theme(z, theme_path)
        clr_map = {}
        if master_path:
            cm = ET.fromstring(z.read(master_path)).find(q("p:clrMap"))
            if cm is not None:
                clr_map = dict(cm.attrib)
        layout_ph = index_placeholders(z, layout_path, warnings)
        master_ph = index_placeholders(z, master_path, warnings)
        root = ET.fromstring(z.read(spath))
        tree = root.find(f"{q('p:cSld')}/{q('p:spTree')}")
        ctx = (theme, clr_map, theme_fonts, layout_ph, master_ph, rels, warnings, fonts_seen)
        shapes = walk_shapes(z, tree, ctx)
        show_master = root.get("showMasterSp", "1") != "0"
        decorations = []
        if show_master:
            for part, layer in ((layout_path, "layout-deco"), (master_path, "master-deco")):
                if part:
                    if part not in deco_cache:
                        deco_cache[part] = non_placeholder_shapes(z, part, ctx, layer)
                    decorations.extend(deco_cache[part])
        bg = extract_background(z, root, layout_path, master_path, theme, clr_map, warnings)
        out_slides.append({
            "index": idx, "part": spath, "layout": layout_path,
            "background": bg, "show_master_shapes": show_master,
            "shape_count": len(shapes), "shapes": shapes,
            "decoration_count": len(decorations), "decorations": decorations,
            "confidence": "measured" if not warnings else "measured-with-warnings",
            "warnings": warnings,
        })

    all_warn = [w for sl in out_slides for w in sl["warnings"]]
    colors = sorted({c for sl in out_slides for s in (sl["shapes"] + sl["decorations"])
                     for c in [s.get("fill"),
                               (s.get("text") or {}).get("first_run", {}).get("color") if s.get("text") else None]
                     if c and not str(c).startswith("scheme:")})
    return {
        "source": str(path), "slide_size": size, "slide_count": len(out_slides),
        "fonts_used": sorted(f for f in fonts_seen if f and not f.startswith("+")),
        "colors_used": colors,
        "confidence": "measured" if not all_warn else "measured-with-warnings",
        "warning_count": len(all_warn),
        "slides": out_slides,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pptx")
    ap.add_argument("-o", "--out", default=None)
    ap.add_argument("--summary", action="store_true")
    args = ap.parse_args()
    try:
        spec = extract(args.pptx)
    except Exception as exc:  # noqa: BLE001 — contract: exit 2, never a raw traceback
        print(f"ERROR: cannot extract: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2
    if args.out:
        Path(args.out).write_text(json.dumps(spec, ensure_ascii=False, indent=1))
        print(f"wrote {args.out}: {spec['slide_count']} slides, fonts={spec['fonts_used']}, "
              f"confidence={spec['confidence']} ({spec['warning_count']} warnings)")
    if args.summary:
        for sl in spec["slides"]:
            kinds = {}
            for s in sl["shapes"]:
                kinds[s["kind"]] = kinds.get(s["kind"], 0) + 1
            print(f"slide {sl['index']:>2}: {sl['shape_count']:>2} shapes {kinds} "
                  f"deco={sl['decoration_count']}"
                  + (f" WARN={len(sl['warnings'])}" if sl["warnings"] else ""))
    if not args.out and not args.summary:
        json.dump(spec, sys.stdout, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
