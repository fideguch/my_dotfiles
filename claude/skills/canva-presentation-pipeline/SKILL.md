---
name: canva-presentation-pipeline
description: >-
  Layout-cloning pipeline for client-ready Canva slide decks. It NEVER invents
  layouts: it first clones the complete layout of a user-provided reference
  deck (geometry, fonts, colors, shapes, spacing, footers — everything except
  content), then swaps only the content in, QAs the result side-by-side
  against the reference, and imports into Canva. Use this whenever the user
  wants a slide deck that will live in Canva or be delivered to a client:
  mentions of "Canva", "Canvaでスライド", "営業資料", "提案書", "ピッチ資料",
  "デッキ", "スライド化", "丸パクリ", "このレイアウトで", or converting an
  outline / 骨子 / deck-spec into a presentation — even when Canva is not
  named explicitly but the deck is client-facing and must match a brand.
---

# Canva Presentation Pipeline v2 — Layout Cloning First

Decks break when an AI invents coordinates. v1 of this skill generated
layouts from scratch and needed 13 visual fixes in QA. v2 removes the cause:
**every layout is cloned from a reference deck a human already designed.**
Content changes; layout does not.

## HARD RULES

1. **No reference, no generation.** A reference deck (PPTX preferred; PDF or
   slide images accepted) must be provided before any slide is produced.
   If none exists, stop and ask the user for one. AI-invented layouts are
   banned in every stage.
2. **Clone everything except content**: positions, sizes, margins, fonts,
   sizes/weights, colors, text-surrounding shapes (chips, cards, circles),
   alignment, footers, page-number style, image crops. Only text, images,
   and data are swapped.
3. **No hand-typed coordinates.** Values come from the reference file itself
   (direct editing) or from machine extraction (`extract_layout.py`).
   All slides sharing a template are filled by one replacement routine —
   per-slide manual tweaks are how inconsistency re-enters.
4. **No layout that is absent from the reference.** Gaps are handled by the
   rules in `references/template-matching.md` (similar-duplication only,
   no resizing) or by asking the user — never by inventing.
5. **Rights gate**: the reference must be the user's own material or a
   template they have rights to use. Confirm at R0 if unclear.

## Two routes, one principle

| Reference format | Route | Fidelity |
|---|---|---|
| **PPTX** | **Direct edit (DEFAULT)**: copy the reference file, replace content only inside identified slots of existing slides, using the Anthropic `pptx` skill's editing workflow (unpack → edit → clean → pack). Masters, layouts, themes, rels stay untouched by construction. | Faithful clone |
| PDF / images | Rebuild via pptxgenjs using ONLY values from `extract_layout.py` / measured layout-spec. Declare it an **approximate clone** to the user. Low measurement confidence → stop and request the PPTX. | Approximate |

Never rebuild when the PPTX exists. Never duplicate slides by naive XML copy
(it corrupts relationships/IDs) — reuse existing slides, or duplicate via the
`pptx` skill's slide tooling which handles relationships, then verify the
file opens in LibreOffice.

## Pipeline

### R0 — Reference intake (HARD GATE)
1. Receive the reference deck; detect format. No file → ask, stop.
2. Rights check (rule 5) if provenance is unclear.
3. Scan for `references/canva-import-profile.yaml` violations (SmartArt,
   native charts, WordArt…) — per slide, declare: editable / rasterize /
   Canva-not-guaranteed.
4. Check the reference's fonts against Canva availability; plan substitutions
   explicitly (recorded in brand-spec `fonts.substitutions`).
5. Reference quality diagnosis (contrast, spacing, resolution). Ask the user
   to choose the mode: **faithful-clone** (defects are reproduced and marked
   user-approved in QA) or **minimal-fix** (corrections listed explicitly and
   excluded from the clone-match check).

### R1 — Layout understanding
- Render every reference slide to an image (thumbnail grid) — this is the
  visual ground truth for QA condition 11.
- PPTX: unpack (via `pptx` skill scripts) and build the **template
  inventory**: one template ID per distinct slide design, with its content
  slots. Placeholder geometry often lives in slideLayout/slideMaster, not the
  slide — resolve the inheritance chain slide → layout → master before
  concluding a shape "has no position". `scripts/extract_layout.py` does this
  resolution and also captures theme colors, group transforms, and image
  srcRect (crop); use it for measurements and later QA comparison.
- PDF/images: `extract_layout.py` cannot help; measure from rendered pages,
  record a confidence level per slide in the layout-spec. Confidence below
  "usable" → stop, request PPTX.

### R2 — Template mapping (contracts)
Write a **template contract** per template ID (see
`references/template-matching.md`): allowed content slots, forbidden changes,
copy budget per slot (max lines / paragraphs / display columns), image-slot
spec (aspect ratio, crop, focal area, mask), and a canonical reference slide.
Then map every deck-spec slide to a template ID
(`validate_deck_spec.py --clone-mode` enforces this) and write the
**allocation manifest** (gen slide → template_id → canonical reference slide
→ reuse|clone|remove) — R4 and compare_layout.py both consume it. Run the
coverage diagnosis (needed purposes vs available templates) BEFORE any
generation; gaps and slide-count changes follow template-matching.md
(§3 ladder, §7 count procedure).

### R3 — Content fitting
- Copy-budget screening first: template-contract budgets (slot-accurate)
  plus `check_copy_limits.py` as the global screen; final wrap verification
  is a real render (soffice) — column arithmetic is a screen, not proof, and
  Japanese line-breaking (禁則) only shows up when rendered.
- Text that does not fit: shorten the CONTENT (propose the shortened wording
  to the user when meaning is at risk — no silent truncation). Never move,
  resize, or shrink a slot to make text fit.
- Images: honor the slot's aspect/crop/focal spec. Never auto-choose
  cover/contain when a subject would be cut — ask or pick a better image.

### R4 — Generation
- **PPTX route**: copy the reference file; replace text run-by-run inside
  slots, preserving run/paragraph properties (bodyPr, lstStyle, bullet
  format, spacing, anchor, autofit); swap images keeping srcRect. All slides
  of one template are processed by ONE replacement routine written for this
  run (rule 3) — that script is a required R4 artifact, not ad-hoc edits.
  Slide count changes follow template-matching.md §7 (duplication via the
  `pptx` skill's `add_slide.py`, removal with rels cleanup). Clean + pack
  with the `pptx` skill scripts, then OPEN-VERIFY: convert with LibreOffice;
  a file that renders all pages is the minimum bar.
- **PDF/image route**: pptxgenjs rebuild from layout-spec values only.

### R5 — QA gate
All conditions in `references/qa-rubric.md`: the original ten (content-driven
breakage can still occur after swapping) plus
**(11) template match** — `compare_layout.py <ref> <gen> --map <manifest>`
must exit 0 (±2pt; derived-template additions whitelisted explicitly) plus a
visual side-by-side — and **(12) zero non-reference layouts** —
`validate_deck_spec.py --clone-mode` exit 0 with derivation provenance for
any derived template. In faithful-clone mode,
reference-inherited defects are marked approved rather than "fixed";
in minimal-fix mode, list every correction. Fresh-eyes subagent inspection
as in the `pptx` skill.

### R6 — Canva import
As in v1: import the PPTX (manual import always works; Canva MCP when
connected). Fonts substituted by Canva can change line breaks even in fixed
boxes — that is why R7 exists.

### R7 — Post-import re-QA (MANDATORY gate)
Screenshot every Canva page and re-check conditions 2–8 and 11 against the
local render. Not connected / not done → say explicitly that post-import
checks are pending. Deliver with the manual-fix list (condition 10).

## Completion contract

Two completion states — never blur them:
- **local-QA-complete**: template inventory + contracts + allocation manifest
  written · every slide mapped · content fitted without slot changes · rubric
  12/12 with evidence (or reference-inherited items marked per mode) ·
  open-verified file · manual-fix list explicit.
- **canva-QA-complete**: the above PLUS the deck imported into Canva and R7
  re-checks passed. Delivering a PPTX with import instructions reaches only
  local-QA-complete — say so explicitly; never report the pipeline as done
  while R7 is pending.

## Validation status of extract_layout.py

`evals/run_extractor_evals.py` is the automated regression suite:
inheritance fixture (tier 2) + adversarial probes (connectors, missing
chOff, flips, unknown elements, theme-font fallback, group-inherited
placeholders) + compare_layout smoke + schema conformance. Run it after any
script change. Tier 1 (a pptxgenjs deck with known coordinates) is a manual
spot-check, not automated. Real decks with exotic constructs (SmartArt,
clrMapOvr, rotated groups): the extractor WARNS and degrades `confidence` —
spot-verify warned slides at R1.

## File map

| Path | Purpose |
|---|---|
| `scripts/extract_layout.py` | PPTX → layout-spec.json (inheritance-resolved geometry, theme colors/fonts, groups, srcRect, backgrounds, layout/master decorations; stdlib only). PPTX-only — for PDF/image references the layout-spec is hand-authored from measurements against the same schema (confidence: visual-estimate) |
| `scripts/compare_layout.py` | QA #11: geometry/style diff generated vs reference (±2pt, manifest map, --allow-added for derived templates) |
| `evals/run_extractor_evals.py` | Automated regression suite for the two scripts above |
| `assets/layout-spec.schema.json` | layout-spec contract |
| `references/template-matching.md` | Template IDs, contracts, nearest-template + duplication rules, coverage diagnosis, gap escalation |
| `references/qa-rubric.md` | 12 completion conditions |
| `references/canva-import-profile.yaml` | What survives Canva PPTX import |
| `references/copy-limits.yaml` | Fallback text budgets (template contracts override) |
| `references/brand-spec.template.yaml` | Brand truth (fonts/subs recorded here) |
| `references/canva-mcp-reference.md` | Canva plugin/MCP setup + Autofill notes |
| `assets/deck-spec.schema.json` | Content contract (unchanged from v1) |
| `scripts/validate_deck_spec.py` / `check_copy_limits.py` | Content validation. `--clone-mode` requires template_id per slide and drops v1's invented structure rules (cover/closing order) |
| `references/slide-archetypes.yaml` | v1 archetype constraints — still read by the validator's non-clone mode |
