# QA Rubric — 10 completion conditions

The deck is not done until every condition below is verified with evidence
(a rendered thumbnail, a script output, or an explicit diff). "Looked fine
while generating" is not evidence. Log a pass/fail table for all 10.

| # | Condition | How to verify |
|---|-----------|---------------|
| 1 | Every point requested in the brief appears on some slide | Diff the brief's claims against deck-spec slide titles/bullets; list each brief point → slide id |
| 2 | No truncated text in titles, bullets, or captions | `check_copy_limits.py` exit 0 AND visual scan of every thumbnail (limits catch most, not all — long unbreakable tokens can still clip) |
| 3 | No overlapping elements | Visual scan of every thumbnail; pptx skill's overlap check where available |
| 4 | No low-contrast text | Text/background pairs meet WCAG AA (4.5:1 body, 3:1 large); check brand palette combos once, then spot-check thumbnails |
| 5 | Logo, colors, fonts match brand-spec.yaml | Compare rendered slides against `brand:` values; any substitution is recorded, not silent |
| 6 | No unnecessary runs of identical layout | validate_deck_spec.py flags >2 consecutive same archetype; confirm visually that variety serves the story |
| 7 | No overstuffed slides | Archetype bullet/row caps respected (script) + thumbnail sanity check: whitespace still visible |
| 8 | No Canva-import-incompatible elements remain | Grep the generation code/output for forbidden items in canva-import-profile.yaml; after import, compare Canva page thumbnails against local ones |
| 9 | Every page's thumbnail was actually rendered and inspected | Thumbnails exist on disk for all N slides; state N and list files |
| 10 | Anything the API cannot fix is on an explicit manual-fix list | Deliver the list with the Canva link — an empty list is stated as empty |

Conditions 2–8 must be re-checked on Canva-side thumbnails after import
(stage 4), because import can shift layout, swap fonts, and drop elements.
