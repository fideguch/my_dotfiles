---
name: canva-presentation-pipeline
description: >-
  End-to-end orchestrator for producing client-ready Canva slide decks with
  reproducible quality. It structures content into a validated deck-spec.json,
  selects the safest generation route (Brand Template Autofill on Enterprise /
  PPTX-then-Canva-import by default / generate-design for exploration only),
  generates slides via the Anthropic pptx skill under a Canva-import-safe
  profile, enforces a 10-point visual QA gate, imports into Canva, and
  finishes with brand-check / get-design-feedback / edit-design. Use this
  whenever the user wants a slide deck that will live in Canva or be delivered
  to a client: mentions of "Canva", "Canvaでスライド", "営業資料", "提案書",
  "ピッチ資料", "デッキ", "スライド化", or converting an outline / 骨子 /
  deck-spec into a presentation — even when Canva is not named explicitly but
  the deck is client-facing and must match a brand.
---

# Canva Presentation Pipeline

Produce decks that survive contact with a client: consistent branding, no
overflowing text, no broken imports — and always editable in Canva afterwards.

This skill is an **orchestrator**. It does not draw slides itself; it decides
the production route, drives generation, and refuses to call the deck done
until the QA gate passes. Layout generation is delegated to the Anthropic
`pptx` skill; Canva-side operations are delegated to the official Canva
plugin skills / Canva MCP when connected.

**When NOT to use:** decks that will never touch Canva (use `md-slides` or
`frontend-slides`), single static graphics (use `canva-design` route C or
plain image tools), and Markdown-only outlines that no one asked to render.

## Inputs

| Input | Where it comes from |
|---|---|
| Content brief / outline | User prompt, or a prepared outline file (e.g. `sales-deck-outline.md`) |
| `brand-spec.yaml` | Resolution order: 1) `./canva/brand-spec.yaml` in the working project → 2) ask the user for brand assets → 3) copy `references/brand-spec.template.yaml` into the project and fill what is known, leaving explicit `TODO:` markers. Never invent hex values or font names silently. |
| `deck-spec.json` | Produced by stage 1 below. This is the single contract between content and layout. Schema: `assets/deck-spec.schema.json`. |

## Pipeline

Run the stages in order. A stage that fails is fixed and re-run, not skipped.

### Stage 0 — Route selection

| Route | When | Mechanism |
|---|---|---|
| **A: Brand Template + Autofill** | Canva **Enterprise** with a prepared Brand Template exists | Claude fills data fields only; layout is human-designed. Highest reproducibility. See `references/canva-mcp-reference.md` §Autofill. |
| **B: PPTX → Canva Import** (DEFAULT) | No Enterprise, or no Brand Template yet | Generate PPTX with the `pptx` skill under the import-safe profile, QA locally, then import into Canva. |
| **C: generate-design** | Exploration / mood-boarding / low-stakes internal decks only | Candidate-based; output is not reproducible. Never the final route for client-facing decks. |

State the chosen route and why in one line before proceeding.

### Stage 1 — Structure content into deck-spec.json

1. Read `references/slide-archetypes.yaml`. Every slide must use one of the
   approved archetypes — free-form layouts are how decks stop looking like
   one deck.
2. Map the brief onto archetypes: cover → executive-summary → body sections →
   recommendation → closing. Prefer one message per slide.
3. Write `deck-spec.json` (see `assets/deck-spec.schema.json` for the shape;
   `evals/fixtures/sample-deck-spec.json` is a working example).
4. Validate — both must exit 0 before continuing:
   ```bash
   python3 scripts/validate_deck_spec.py deck-spec.json
   python3 scripts/check_copy_limits.py deck-spec.json
   ```
   These enforce archetype constraints and Japanese-aware text-width limits
   (`references/copy-limits.yaml`). Fix the spec, not the validator.

### Stage 2 — Generate (route B shown; route A/C in canva-mcp-reference.md)

1. Read `references/canva-import-profile.yaml` FIRST and keep it in view
   while generating: Canva's PPTX import silently drops or replaces native
   PowerPoint charts, SmartArt, WordArt, 3D objects, pattern fills, and
   unavailable fonts. Anything the profile forbids must not enter the PPTX.
2. Charts and diagrams: render to SVG/PNG before insertion (matplotlib →
   PNG, or hand-built SVG). Never use native PPTX chart objects.
3. Fonts: use only fonts listed in `brand-spec.yaml` `fonts:` (which must be
   names that exist in the Canva brand kit / Canva font library).
4. Generate the PPTX with the Anthropic `pptx` skill, one slide per
   deck-spec entry, honoring each archetype's layout constraints.

### Stage 3 — Local QA gate

Render every slide to an image (the `pptx` skill provides thumbnailing) and
check ALL TEN conditions in `references/qa-rubric.md`. The deck is not
"generated" until the rubric passes; log each condition as pass/fail with
evidence. Failing conditions loop back to stage 1 or 2.

### Stage 4 — Import into Canva

- Canva plugin/MCP connected → import the PPTX (`import-design-from-url` /
  Design Import API path), then fetch thumbnails of every page and re-check
  rubric conditions 2–8 (import can shift layout).
- Not connected → hand the user: the QA-passed PPTX, one-line import
  instructions (Canva → Create → Import file), and the setup commands from
  `references/canva-mcp-reference.md` §Setup for next time. Do not silently
  end the pipeline: say explicitly that post-import checks are pending.

### Stage 5 — Canva-side finishing

With the official Canva skills: `brand-check` against the brand kit,
`get-design-feedback` for visual issues, `implement-feedback` / `edit-design`
for fixes. Anything the API cannot fix goes into the **manual-fix list**
(rubric condition 10) — never claim full completion while that list is
non-empty; deliver the Canva edit link together with the list.

## Completion contract

Done means: deck-spec validated · rubric 10/10 with evidence · Canva edit
link delivered (or QA-passed PPTX + import instructions when Canva is not
connected) · manual-fix list explicitly empty or handed over.

## File map

| Path | Purpose |
|---|---|
| `references/brand-spec.template.yaml` | Copy into project as `canva/brand-spec.yaml`; single source of brand truth |
| `references/slide-archetypes.yaml` | Approved slide types + per-type constraints |
| `references/copy-limits.yaml` | Text width/line limits (CJK display-width aware) |
| `references/canva-import-profile.yaml` | What may / may not enter a Canva-bound PPTX |
| `references/qa-rubric.md` | The 10 completion conditions and how to verify each |
| `references/canva-mcp-reference.md` | Canva plugin/MCP setup, tool inventory, Autofill (route A), import API notes |
| `assets/deck-spec.schema.json` | deck-spec.json contract |
| `scripts/validate_deck_spec.py` | Structural + archetype validation (stdlib only) |
| `scripts/check_copy_limits.py` | Text overflow linter (stdlib only) |
| `evals/` | Representative briefs + benchmark rubric for skill evaluation |
