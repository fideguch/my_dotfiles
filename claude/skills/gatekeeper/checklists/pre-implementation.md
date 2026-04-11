# Pre-Implementation Checklist (HG-1 + UX Protocol)

> Execute this checklist BEFORE writing any implementation code.
> Every item must be checked. Skipping any item = HG-1 violation.

## Spec Reading

- [ ] Read ALL relevant files in designs/ for the target feature
- [ ] Read designs/component-definitions.md for component specs
- [ ] Read designs/design-system.md for token values
- [ ] Grep for the feature keyword across designs/:
  ```bash
  grep -rl "feature_keyword" designs/
  ```

## Figma Verification

- [ ] Called get_design_context with the target screen's nodeId
- [ ] Captured screenshot for visual reference
- [ ] Extracted text content from Figma response
- [ ] Compared Figma output with designs/ markdown (documents override on conflict)

## Existing Pattern Check

- [ ] Grepped for similar patterns in Phase 3 screens:
  ```bash
  grep -rl "similar_component" src/app/ src/components/
  ```
- [ ] Identified reusable components (list them):
  - Component 1: ___
  - Component 2: ___
- [ ] Confirmed layout pattern (GlobalHeader + content + BottomNav/FixedCTABar)

## UX Thinking Protocol

- [ ] Filled in the UX template:
  ```
  SCREEN: ___
  USER GOAL: ___
  FIRST ACTION: ___
  HAPPY PATH: ___ -> ___ -> ___ -> ___
  ERROR PATH: ___
  EDGE CASES: ___
  ```

## Questions

- [ ] All unclear points identified
- [ ] Checked designs/ before asking user (grep first, ask second)
- [ ] Questions asked one at a time, answers received

## Gate Status

```
HG-1: [ ] PASS / [ ] FAIL
Evidence: [list of files read, Figma screens checked]
```
