# Research Validation Checklist (Category 8 Prevention)

> Execute this checklist BEFORE adopting any competitive research or
> external pattern into implementation decisions.
> Research = input, NOT decision. Always confirm with user.

## Source Validation

- [ ] Research source identified (Airbnb, competitor, blog post, etc.)
- [ ] Research is from a reputable source (official docs, engineering blog, peer-reviewed)
- [ ] Research is current (check date — APIs and patterns change)

## Implementation Cost Assessment

- [ ] Estimated number of files to change: ___
- [ ] DB schema changes required? [ ] Yes / [ ] No
  - If Yes: estimated migration complexity: ___
- [ ] Breaks existing patterns? [ ] Yes / [ ] No
  - If Yes: list what breaks: ___
- [ ] Simpler alternative exists? [ ] Yes / [ ] No
  - If Yes: describe: ___

## User Confirmation

- [ ] Presented research finding to user with:
  - What: the pattern/approach found
  - Cost: estimated implementation effort
  - Alternative: simpler option if available
- [ ] User confirmed adoption: [ ] Yes / [ ] No / [ ] Modified

## Existing Pattern Compatibility

- [ ] Checked Phase 3 patterns for conflicts
- [ ] DS token compliance verified
- [ ] Component reuse opportunities identified

## Gate Status

```
Research validation: [ ] APPROVED / [ ] REJECTED / [ ] MODIFIED
User decision: ___
```
