# Type B Plan Quality Gate Checklist

> Type B (spec/prompt/config) changes require different plan validation than code.
> Referenced by SKILL.md Step 3 when `type == B`.

## When to Apply

Plan Quality Gate dispatches this checklist instead of code-focused gates when:
- Change target classified as Type B
- Modified files include `.md` prompts, SKILL.md, YAML/JSON config, HARD-GATE definitions

## Checklist

### 1. SSOT Mapping

Each piece of information must have exactly ONE authoritative source file.

```
[ ] Identify the authoritative file for each data point being changed
[ ] Grep for the same data in other files — flag duplicates
[ ] If duplicates exist: plan must include updating ALL or referencing the SSOT
```

Evidence: `grep -rn "[data_point]" [project_root]` output showing occurrence count.

### 2. Reference Integrity

Every cross-reference ("see Section X", "per file Y") must resolve.

```
[ ] List all cross-references in changed files
[ ] Verify each target exists (file, section heading, anchor)
[ ] If target missing: plan must CREATE it or REMOVE the reference
```

Evidence: `grep -n "参照\|see \|ref:\|Section\|セクション" [changed_files]` + resolution check.

### 3. Count Consistency

Numerical claims (table rows, screen count, category count) must match across files.

```
[ ] Identify all countable items mentioned in changed files
[ ] Cross-check counts against source files
[ ] If mismatch: plan must reconcile to single source of truth
```

Evidence: `grep -c` or `wc -l` output for each countable item.

### 4. Version Consistency

Version strings must be identical across all files in the change-set.

```
[ ] Grep for version patterns (vN.N, version: N.N) in all changed files
[ ] Confirm all match the intended version
[ ] If mismatch: plan must update all to single version
```

Evidence: `grep -rn "v[0-9]\+\.[0-9]" [changed_files]` output.

### 5. Terminology Consistency

Terms that should be unified must be consistent across all files.

```
[ ] Identify domain-specific terms in the change
[ ] Grep for variant spellings/synonyms across all project files
[ ] If inconsistent: plan must standardize to one term
```

Evidence: `grep -rn "[term_variant]" [project_root]` showing unified usage.

## Pass/Fail

- **All 5 PASS**: Proceed to Writer dispatch
- **Any FAIL**: Planner revises (max 2 iterations), then human decides
- Evidence carry-forward: SSOT map + reference list -> Writer (context) + Guardian (verification)
