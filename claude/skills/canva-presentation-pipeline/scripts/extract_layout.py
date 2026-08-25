#!/usr/bin/env python3
"""Extract a machine-readable layout-spec from a PPTX.

Purpose (skill v2): layouts are cloned, never invented. This tool provides
the measured ground truth — for the PDF/image rebuild route it is the source
of coordinates; for the PPTX direct-edit route it powers QA condition #11
(template-match geometry diff).

Resolves the placeholder inheritance chain slide -> slideLayout ->
slideMaster (geometry frequently lives on the layout/master, not the slide),
theme scheme colors (via the master's clrMap), group transforms, and image
crops (srcRect). Stdlib only.

Exit codes: 0 ok, 2 unreadable input.
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
}
EMU_PER_IN = 914400.0


def q(tag):
    pfx, local = tag.split(":")
    return f"{{{NS[pfx]}}}{local}"


def parse_rels(z, part_path):
    """Return {rId: target} with targets resolved relative to the part's dir."""
    p = Path(part_path)
    rels_path = str(p.parent / "_rels" / (p.name + ".rels"))
    out = {}
    if rels_path not in z.namelist():
        return out
    root = ET.fromstring(z.read(rels_path))
    for rel in root:
        rid = rel.get("Id")
        target = rel.get("Target")
        if rel.get("TargetMode") == "External":
            out[rid] = target
            continue
        base = p.parent
        t = Path(target)
        parts = list(base.parts)
        for seg in t.parts:
            if seg == "..":
                parts.pop()
            elif seg != ".":
                parts.append(seg)
        out[rid] = "/".join(parts)
    return out


def load_theme(z, theme_path):
    scheme = {}
    if not theme_path or theme_path not in z.namelist():
        return scheme
    root = ET.fromstring(z.read(theme_path))
    clr = root.find(f"{q('a:themeElements')}/{q('a:clrScheme')}")
    if clr is None:
        return scheme
    for child in clr:
        name = child.tag.split("}")[1]
        srgb = child.find(q("a:srgbClr"))
        sysc = child.find(q("a:sysClr"))
        if srgb is not None:
            scheme[name] = srgb.get("val")
        elif sysc is not None:
            scheme[name] = sysc.get("lastClr", "000000")
    return scheme


def resolve_color(elem, theme, clr_map, warnings):
    """elem: parent that may contain srgbClr/schemeClr/sysClr. -> hex or None"""
    if elem is None:
        return None
    srgb = elem.find(q("a:srgbClr"))
    if srgb is not None:
        return srgb.get("val")
    sch = elem.find(q("a:schemeClr"))
    if sch is not None:
        val = sch.get("val")
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
    return {
        "x": int(off.get("x")), "y": int(off.get("y")),
        "cx": int(ext.get("cx")), "cy": int(ext.get("cy")),
        "rot": int(xfrm.get("rot", "0")),
    }


def ph_key(nv_pr):
    if nv_pr is None:
        return None
    ph = nv_pr.find(q("p:ph"))
    if ph is None:
        return None
    return (ph.get("type", "body"), ph.get("idx", "0"))


def index_placeholders(z, part):
    """(type, idx) -> xfrm dict, for a layout or master part."""
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
            out[key] = xf
    return out


def text_info(sp, theme, clr_map, warnings):
    tx = sp.find(q("p:txBody"))
    if tx is None:
        return None
    body_pr = tx.find(q("a:bodyPr"))
    paras = tx.findall(q("a:p"))
    chars, first = 0, None
    has_bullet = False
    for para in paras:
        ppr = para.find(q("a:pPr"))
        if ppr is not None and (ppr.find(q("a:buChar")) is not None or ppr.find(q("a:buAutoNum")) is not None):
            has_bullet = True
        for run in para.findall(q("a:r")):
            t = run.find(q("a:t"))
            text = t.text or "" if t is not None else ""
            chars += len(text)
            if first is None and text.strip():
                rpr = run.find(q("a:rPr"))
                first = {
                    "size_pt": int(rpr.get("sz")) / 100 if rpr is not None and rpr.get("sz") else None,
                    "bold": rpr is not None and rpr.get("b") == "1",
                    "color": resolve_color(rpr.find(q("a:solidFill")) if rpr is not None else None, theme, clr_map, warnings),
                    "font": (rpr.find(q("a:latin")).get("typeface") if rpr is not None and rpr.find(q("a:latin")) is not None else None),
                    "font_ea": (rpr.find(q("a:ea")).get("typeface") if rpr is not None and rpr.find(q("a:ea")) is not None else None),
                }
    align = None
    p0 = paras[0].find(q("a:pPr")) if paras else None
    if p0 is not None:
        align = p0.get("algn")
    return {
        "first_run": first,
        "align": align,
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
    return {
        "x_in": round(x / EMU_PER_IN, 3), "y_in": round(y / EMU_PER_IN, 3),
        "w_in": round(cx / EMU_PER_IN, 3), "h_in": round(cy / EMU_PER_IN, 3),
        "rot_deg": round(xf.get("rot", 0) / 60000, 1),
    }


def walk_shapes(z, tree, theme, clr_map, layout_ph, master_ph, rels, warnings, scale=None, in_group=False):
    shapes = []
    for child in tree:
        tag = child.tag
        if tag == q("p:sp"):
            nv = child.find(f"{q('p:nvSpPr')}/{q('p:nvPr')}")
            name_el = child.find(f"{q('p:nvSpPr')}/{q('p:cNvPr')}")
            key = ph_key(nv)
            sp_pr = child.find(q("p:spPr"))
            xf = get_xfrm(sp_pr)
            src = "slide"
            if xf is None and key is not None:
                if key in layout_ph:
                    xf, src = layout_ph[key], "layout"
                elif key in master_ph:
                    xf, src = master_ph[key], "master"
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
                "geometry_from": src, "in_group": in_group,
                **emu_box(xf, scale),
                "preset": geom.get("prst") if geom is not None else None,
                "fill": fill,
                "line": {"color": resolve_color(ln.find(q("a:solidFill")), theme, clr_map, warnings),
                         "w_pt": round(int(ln.get("w")) / 12700, 2) if ln.get("w") else None} if ln is not None else None,
                "text": text_info(child, theme, clr_map, warnings),
            })
        elif tag == q("p:pic"):
            name_el = child.find(f"{q('p:nvPicPr')}/{q('p:cNvPr')}")
            xf = get_xfrm(child.find(q("p:spPr")))
            if xf is None:
                warnings.append("picture without geometry")
                continue
            blip = child.find(f"{q('p:blipFill')}/{q('a:blip')}")
            src_rect = child.find(f"{q('p:blipFill')}/{q('a:srcRect')}")
            shapes.append({
                "kind": "image",
                "name": name_el.get("name") if name_el is not None else None,
                "geometry_from": "slide", "in_group": in_group,
                **emu_box(xf, scale),
                "image": {
                    "target": rels.get(blip.get(q("r:embed"))) if blip is not None else None,
                    "srcRect_pct": {k: int(src_rect.get(k, "0")) / 1000 for k in ("l", "t", "r", "b")} if src_rect is not None else None,
                },
            })
        elif tag == q("p:graphicFrame"):
            xf_el = child.find(q("p:xfrm"))
            if xf_el is not None:
                off, ext = xf_el.find(q("a:off")), xf_el.find(q("a:ext"))
                xf = {"x": int(off.get("x")), "y": int(off.get("y")),
                      "cx": int(ext.get("cx")), "cy": int(ext.get("cy")), "rot": 0}
                has_table = child.find(f".//{q('a:tbl')}") is not None
                shapes.append({"kind": "table" if has_table else "graphicFrame",
                               "geometry_from": "slide", "in_group": in_group, **emu_box(xf, scale)})
        elif tag == q("p:grpSp"):
            grp_pr = child.find(q("p:grpSpPr"))
            xfrm = grp_pr.find(q("a:xfrm")) if grp_pr is not None else None
            if xfrm is None:
                warnings.append("group without transform — children skipped")
                continue
            off, ext = xfrm.find(q("a:off")), xfrm.find(q("a:ext"))
            ch_off, ch_ext = xfrm.find(q("a:chOff")), xfrm.find(q("a:chExt"))
            gx, gy = int(off.get("x")), int(off.get("y"))
            cx, cy = int(ext.get("cx")), int(ext.get("cy"))
            chx, chy = int(ch_off.get("x")), int(ch_off.get("y"))
            chcx = int(ch_ext.get("cx")) or cx
            chcy = int(ch_ext.get("cy")) or cy
            sub_scale = (gx, gy, cx / chcx, cy / chcy, chx, chy)
            shapes.extend(walk_shapes(z, child, theme, clr_map, layout_ph, master_ph, rels, warnings,
                                      scale=sub_scale, in_group=True))
    return shapes


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

    out_slides, all_warn = [], []
    for idx, spath in enumerate(slide_paths, 1):
        warnings = []
        rels = parse_rels(z, spath)
        layout_path = next((t for t in rels.values() if t and "slideLayout" in t), None)
        layout_rels = parse_rels(z, layout_path) if layout_path else {}
        master_path = next((t for t in layout_rels.values() if t and "slideMaster" in t), None)
        master_rels = parse_rels(z, master_path) if master_path else {}
        theme_path = next((t for t in master_rels.values() if t and "theme" in t), None)
        theme = load_theme(z, theme_path)
        clr_map = {}
        if master_path:
            mroot = ET.fromstring(z.read(master_path))
            cm = mroot.find(q("p:clrMap"))
            if cm is not None:
                clr_map = dict(cm.attrib)
        layout_ph = index_placeholders(z, layout_path)
        master_ph = index_placeholders(z, master_path)
        root = ET.fromstring(z.read(spath))
        tree = root.find(f"{q('p:cSld')}/{q('p:spTree')}")
        shapes = walk_shapes(z, tree, theme, clr_map, layout_ph, master_ph, rels, warnings)
        out_slides.append({
            "index": idx, "part": spath, "layout": layout_path,
            "shape_count": len(shapes), "shapes": shapes, "warnings": warnings,
        })
        all_warn.extend(warnings)

    fonts = sorted({s["text"]["first_run"]["font"] for sl in out_slides for s in sl["shapes"]
                    if s.get("text") and s["text"].get("first_run") and s["text"]["first_run"].get("font")} |
                   {s["text"]["first_run"]["font_ea"] for sl in out_slides for s in sl["shapes"]
                    if s.get("text") and s["text"].get("first_run") and s["text"]["first_run"].get("font_ea")})
    colors = sorted({c for sl in out_slides for s in sl["shapes"]
                     for c in [s.get("fill"), (s.get("text") or {}).get("first_run", {}).get("color") if s.get("text") else None]
                     if c and not str(c).startswith("scheme:")})
    return {
        "source": str(path), "slide_size": size, "slide_count": len(out_slides),
        "fonts_used": [f for f in fonts if f], "colors_used": colors,
        "confidence": "measured" if not all_warn else "measured-with-warnings",
        "slides": out_slides,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pptx")
    ap.add_argument("-o", "--out", default=None)
    ap.add_argument("--summary", action="store_true", help="print per-slide shape summary instead of full JSON")
    args = ap.parse_args()
    try:
        spec = extract(args.pptx)
    except (OSError, zipfile.BadZipFile, ET.ParseError, KeyError) as exc:
        print(f"ERROR: cannot extract: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2
    if args.out:
        Path(args.out).write_text(json.dumps(spec, ensure_ascii=False, indent=1))
        print(f"wrote {args.out}: {spec['slide_count']} slides, "
              f"fonts={spec['fonts_used']}, confidence={spec['confidence']}")
    if args.summary:
        for sl in spec["slides"]:
            kinds = {}
            for s in sl["shapes"]:
                kinds[s["kind"]] = kinds.get(s["kind"], 0) + 1
            inh = sum(1 for s in sl["shapes"] if s["geometry_from"] != "slide")
            print(f"slide {sl['index']:>2}: {sl['shape_count']:>2} shapes {kinds}"
                  + (f" inherited-geom={inh}" if inh else "")
                  + (f" WARN={len(sl['warnings'])}" if sl["warnings"] else ""))
    if not args.out and not args.summary:
        json.dump(spec, sys.stdout, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
