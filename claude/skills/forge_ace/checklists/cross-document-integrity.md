# Cross-Document Integrity Checklist

> Guardian Phase 2 Type B branch. Replaces blast-radius analysis for spec/prompt/config changes.
> Loaded when Guardian detects Type B change target.

## 1. Version Consistency

```bash
grep -rn "v[0-9]\+\.[0-9]" [CHANGED_FILES] [RELATED_FILES]
```

- [ ] All version strings match the intended version
- [ ] No stale version references in unchanged sections
- Flag: VERSION_MISMATCH if any divergence

## 2. Count Consistency

```bash
# Example: count table rows, screen definitions, category entries
grep -c "^|" [FILE]          # table rows
grep -c "##" [FILE]          # section count
grep -c "screen\|画面" [FILE] # screen references
```

- [ ] Table row counts match claimed totals
- [ ] Screen/page counts match across spec files
- [ ] Category/enum counts consistent between definition and usage
- Flag: COUNT_MISMATCH with expected vs actual

## 3. SSOT Violation Search

```bash
# Detect hardcoded values that should reference a single source
grep -rn "[specific_value]" [PROJECT_SPEC_FILES] | wc -l
```

- [ ] Each data point appears in exactly ONE authoritative file
- [ ] Other files reference the SSOT, not duplicate the value
- [ ] If value appears in N>1 files: verify all N are identical
- Flag: SSOT_VIOLATION with file list and divergent values

## 4. Reference Existence

```bash
# Check that "see Section X" / "参照: file.md" targets exist
grep -n "参照\|see \|ref:" [CHANGED_FILES]
# Then verify each target
head -1 [referenced_file]    # file exists?
grep -n "[section_name]" [referenced_file]  # section exists?
```

- [ ] Every file reference resolves to an existing file
- [ ] Every section reference resolves to an existing heading
- [ ] No dangling references introduced by this change
- Flag: BROKEN_REFERENCE with source location and missing target

## 5. Terminology Consistency

```bash
# Check for variant spellings of key domain terms
grep -rn "消費者\|一般家庭\|個人ユーザー" [PROJECT_SPEC_FILES]
```

- [ ] Domain terms are used consistently across all files
- [ ] No synonym variants introduced by this change
- [ ] Glossary/terminology section (if exists) matches usage
- Flag: TERM_INCONSISTENCY with variants found and file locations

## Judgment Integration

Report format in Guardian's output:

```
**Cross-Document Integrity:**
| Check | Result | Evidence |
|-------|--------|----------|
| Version | PASS/FAIL | [grep output] |
| Count | PASS/FAIL | [expected vs actual] |
| SSOT | PASS/FAIL | [file list] |
| Reference | PASS/FAIL | [broken refs] |
| Terminology | PASS/FAIL | [variants] |
```

Any FAIL -> GUARDIAN_REJECTED with specific remediation.
