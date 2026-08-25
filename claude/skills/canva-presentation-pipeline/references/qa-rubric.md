# QA Rubric — 12 completion conditions

The deck is not done until every condition is verified with evidence
(a rendered thumbnail, a script output, or an explicit diff). "Looked fine
while generating" is not evidence. Log a pass/fail table for all 12.

| # | Condition | How to verify |
|---|-----------|---------------|
| 1 | Every point requested in the brief appears on some slide | Diff the brief's claims against deck-spec slide titles/bullets; list each brief point → slide id |
| 2 | No truncated text in titles, bullets, or captions | `check_copy_limits.py` exit 0 AND real-render wrap check (column math is a screen, not proof) AND visual scan of every thumbnail |
| 3 | No overlapping elements | Visual scan of every thumbnail |
| 4 | No low-contrast text | Text/background pairs meet WCAG AA (4.5:1 body, 3:1 large). Reference-inherited failures: see rubric mode note below |
| 5 | Logo, colors, fonts match brand-spec.yaml (or the reference deck when cloning) | Compare rendered slides; any substitution recorded, not silent |
| 6 | No unnecessary runs of identical layout | Repetition limits of template-matching.md §4 respected |
| 7 | No overstuffed slides | Template contract copy budgets respected + whitespace matches the reference |
| 8 | No Canva-import-incompatible elements remain | R0 scan results resolved; post-import thumbnails compared |
| 9 | Every page's thumbnail was actually rendered and inspected | Thumbnails exist for all N slides; state N and list files |
| 10 | Anything the API cannot fix is on an explicit manual-fix list | Deliver the list with the deck — an empty list is stated as empty |
| 11 | **Template match**: each slide, side-by-side with its reference template slide, shows identical layout | Compare renders; measure offsets (extract_layout.py geometry diff where PPTX); tolerance ±2pt equivalent; report measured deltas per slide |
| 12 | **Zero non-reference layouts** | Every slide's template_id maps to a reference slide; no slide uses invented geometry |

Mode note (set at R0): in **faithful-clone** mode, a condition failed by the
reference itself is marked "reference-inherited, user-approved" instead of
fixed; in **minimal-fix** mode it is corrected and listed, and the corrected
shapes are excluded from condition 11. Conditions 2–8 and 11 must be
re-checked on Canva-side screenshots after import (R7) — import can swap
fonts and shift line breaks.
