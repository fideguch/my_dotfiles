# Template matching — inventory, contracts, gap rules

## 1. Template inventory (R1 output)

Group the reference slides by distinct design. One **template ID** (T1..Tn)
per design, not per slide — five look-alike body slides are one template.
For each template record:

```yaml
- id: T3
  source_slides: [4, 7, 9]        # reference slide indices using this design
  purpose: "two-column comparison"
  slots:
    - {slot: title,   kind: text,  max_lines: 1}
    - {slot: col_l_head, kind: text, max_lines: 1}
    - {slot: col_l_body, kind: bullets, max_items: 4, max_lines_each: 2}
    - {slot: col_r_head, kind: text, max_lines: 1}
    - {slot: col_r_body, kind: bullets, max_items: 4, max_lines_each: 2}
    - {slot: image_1, kind: image, aspect: 1.6, crop: keep, focal: center}
  forbidden: [moving/resizing any shape, changing fonts/sizes/colors,
              adding shapes not present in the template]
```

The `slots` + `forbidden` block is the **template contract**. Copy budgets
(max_items / max_lines) come from what the reference slide actually holds,
measured, not guessed. Every generated slide must satisfy its contract.

## 2. Mapping deck-spec slides to templates

Map by purpose, not by name: cover→cover-like template, comparison table→the
reference's table-ish template, etc. Record the mapping in deck-spec as
`"template_id": "T3"` per slide.

## 3. Coverage diagnosis (run BEFORE generating anything)

List needed slide purposes vs available templates. For each gap decide by
this ladder — stop at the first rung that works:

1. **Reuse**: a different template serves the purpose acceptably
   (e.g. two-column template for a vs-comparison).
2. **Similar duplication**: replicate an existing repeating element of the
   SAME template (e.g. the reference shows 3 identical list rows, content
   needs 4 → clone one row at the same size and pitch). Duplication must be
   congruent — same dimensions, same spacing step. Resizing is forbidden.
   If the extra copy would leave the reference's visual bounds, it does not
   fit — go to rung 3.
3. **Content reduction**: summarize the content to fit existing structure
   (propose wording to the user when meaning is at risk).
4. **Ask the user**: request an additional reference slide of the needed
   type, or explicit permission to leave that content out.

Inventing a new layout is not on the ladder.

## 4. Repetition limits

Same template on consecutive slides: acceptable up to the longest run the
reference itself exhibits; beyond that, interleave other templates or ask.
A deck that uses one template for 12 of 16 slides will read as machine-made
even with perfect geometry.

## 5. Quantity mismatch (reference slot ≠ content amount)

- Content SMALLER than reference (2 bullets in a 4-bullet slot): fill fewer
  items, keep positions of the remaining items exactly as in the reference
  (do not re-center or redistribute).
- Content LARGER: rung 2 (congruent duplication) if the template repeats the
  element, else rung 3 (reduce). Never shrink fonts or spacing.

## 6. Reference-defect escalation

When the reference itself violates QA conditions (low contrast, collisions):
- faithful-clone mode → reproduce, and mark the affected QA condition
  "reference-inherited, user-approved".
- minimal-fix mode → correct it, list every correction, and exclude those
  shapes from the template-match check (#11).
The mode is chosen by the user at R0; do not mix modes silently.
