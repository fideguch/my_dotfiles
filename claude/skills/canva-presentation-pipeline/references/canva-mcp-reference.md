# Canva plugin / MCP reference

## Setup (user-side, one time)

Run inside Claude Code (these are CLI built-ins, the user must run them):

```
/plugin marketplace add canva-sdks/canva-skills
/plugin install canva@canva-skills
```

Then complete the Canva OAuth prompt. The plugin uses the official Canva MCP
server (works in Claude Code, Claude Desktop, Cursor, Codex). Prefer this
official route over hand-rolled Connect API clients; use the Connect API
directly only when embedding into a product backend.

## Official skill families (active as of 2026-08)

| Skill | Use in this pipeline |
|---|---|
| `edit-design` | Stage 5 fixes |
| `get-design-feedback` | Stage 5 visual review (works from thumbnails) |
| `brand-check` | Stage 5 brand conformance vs Brand Kit |
| `implement-feedback` | Apply review comments |
| `bulk-create` | Variant decks from data (not part of the default flow) |
| `resize-for-social-media` | Out of scope for decks |

`branded-presentation` (outline → deck candidates) exists in the repo but is
**inactive** — treat it as a reference implementation only, never a
production dependency.

Note: the official feedback skill itself works primarily from page
thumbnails, not guaranteed-accurate API color/font values — which is exactly
why brand truth lives in the project's local `brand-spec.yaml`.

## Route A — Brand Template + Autofill (Enterprise only)

Human designs a Brand Template with named data fields; the pipeline validates
deck-spec, autofills fields (text, images, some chart data), fetches all page
thumbnails, then runs brand-check → edit-design. Claude never invents layout.
Requires: Canva Enterprise + Autofill API. If `canva.plan` in brand-spec is
not `enterprise`, this route is unavailable — say so and use route B.

## Route B — PPTX import notes

- Import path: Canva MCP `import-design-from-url`, Design Import API, or
  manual (Canva → Create → Import file). Manual always works — offer it when
  the MCP is not connected.
- Import constraints live in `canva-import-profile.yaml`. Re-verify layout on
  Canva-side thumbnails after import (QA rubric conditions 2–8).

## Route C — generate-design

Candidate-based generation (prompt → several candidates → pick → editable
design). Non-reproducible by design. Allowed uses: exploring visual
directions, template scouting, low-stakes internal decks. Not allowed as the
final route for client-facing, sales, IR, or brand material.
