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
| 11 | **Template match**: each slide, side-by-side with its canonical reference slide, shows identical layout | `compare_layout.py <ref> <gen> --map <allocation manifest>` exits 0 (±2pt; derived-template additions whitelisted via --allow-added); PLUS visual side-by-side of renders with content areas mentally masked — text/images differ by design, geometry must not |
| 12 | **Zero non-reference layouts** | `validate_deck_spec.py --clone-mode` exit 0 AND every template_id resolves in the template inventory AND derived templates carry recorded provenance (source slide + derivation rule). A template_id label alone proves nothing — the compare in #11 is the geometric proof |

Mode note (set at R0): in **faithful-clone** mode, a condition failed by the
reference itself is marked "reference-inherited, user-approved" instead of
fixed; in **minimal-fix** mode it is corrected and listed, and the corrected
shapes are excluded from condition 11. Conditions 2–8 and 11 must be
re-checked on Canva-side screenshots after import (R7) — import can swap
fonts and shift line breaks.

Fresh-eyes review packet (condition 9's inspection): give the subagent BOTH
renders — generated slide and its canonical reference slide side by side —
with the checklist "same positions, same shapes, same fonts/sizes/colors;
only content differs". A review without the reference next to it cannot
judge #11.
