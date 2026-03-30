# Scenario S: Documentation Fix (Standard-tier)

Standard-tier test scenario for forge_ace. Demonstrates the 4-agent flow
(Writer + Guardian + Overseer-standard + PM-Admin-standard)
on a documentation-only change with full quality gate enforcement.

## Scenario Context

**Task:** Fix outdated API endpoint path in `docs/api-reference.md`.
The doc references `POST /api/v1/users/create` but the actual endpoint
was renamed to `POST /api/v2/users` in a recent migration.

**Tier Classification:**
```
Standard: All code/spec changes (no UI)
→ Writer + Guardian + Overseer(standard) + PM-Admin(standard)
```

**Flow:** `Writer → Guardian → Overseer(standard) → PM-Admin(standard) → DONE`

---

## Writer Execution

### Phase 0: Comprehension

```bash
# Evidence-of-Execution: verify the file exists and find the outdated reference
$ grep -n "v1/users/create" docs/api-reference.md
47:  POST /api/v1/users/create

# Verify the actual endpoint in source code
$ grep -rn "v2/users" src/routes/users.ts
12:  router.post('/api/v2/users', createUserHandler);
```

### Phase 2: Implementation

Single-line fix in `docs/api-reference.md` line 47:
```diff
-  POST /api/v1/users/create
+  POST /api/v2/users
```

Also updated the curl example on line 53:
```diff
-  curl -X POST https://api.example.com/v1/users/create \
+  curl -X POST https://api.example.com/v2/users \
```

### Writer Report

<writer_report>

### Status
DONE

### Before/After Specification
```
File: docs/api-reference.md
BEFORE: References deprecated endpoint POST /api/v1/users/create
AFTER:  References current endpoint POST /api/v2/users
DELTA:  2 lines updated (endpoint path + curl example)
RISK:   LOW — documentation only, no runtime impact
```

### Files Changed
| File | Change Type | Description |
|------|------------|-------------|
| docs/api-reference.md | MODIFY | Update endpoint path and curl example |

### Tests
- New tests written: 0 (documentation-only change)
- Existing tests affected: 0
- Test run result: N/A (no executable tests for .md files)
- **Test execution evidence:** Verified endpoint exists in source:
  `grep -rn "v2/users" src/routes/users.ts → line 12: router.post('/api/v2/users', ...)`

### 30% Check Results
- Edge cases: CLEAR (text-only change)
- Security: CLEAR (no code execution path)
- Integration: CLEAR (no imports or type contracts)
- Concurrency: CLEAR (N/A for documentation)

### Red Team Results
- Input fuzzing: N/A
- State corruption: N/A
- Dependency failure: N/A
- Privilege escalation: N/A

### Anti-Pattern Scan
- Spec-as-Done: CLEAR — this IS the doc fix, not a spec for future work
- Phantom Addition: CLEAR — Read file first, confirmed line 47 exists before modifying
- High-Risk-Gap: CLEAR — no session-external work required
- Precondition-as-Assumption: CLEAR — no tests with hidden preconditions
- Disconnected-Bloodline: N/A — no external connections referenced

### Self-Review Findings
None. Straightforward text replacement verified against source code.

### Confidence
95%

</writer_report>

---

## Guardian Execution

### Phase 0: Independent Verification (VP-1)

```bash
# Verify the file was actually changed (not just claimed)
$ git diff docs/api-reference.md
-  POST /api/v1/users/create
+  POST /api/v2/users
-  curl -X POST https://api.example.com/v1/users/create \
+  curl -X POST https://api.example.com/v2/users \

# Independent confirmation: the new endpoint path matches source
$ grep -c "v2/users" src/routes/users.ts
1
```

### Phase 0.5: Risk-Tier Routing

```
Risk Tier: LOW
Reasoning: diff touches 0 production code lines, documentation-only (.md),
no runtime behavior change, no API surface modification.
```

### Phase 5.5: Quality Standards 8-Axis

| # | Axis | Result | Evidence |
|---|------|--------|----------|
| 1 | Design & Architecture | PASS | Doc structure preserved |
| 2 | Functionality & Correctness | PASS | Endpoint matches `src/routes/users.ts:12` |
| 3 | Complexity & Readability | PASS | Clear, minimal change |
| 4 | Testing & Reliability | PASS | N/A for docs; source grep is sufficient |
| 5 | Security | PASS | No secrets, no code paths |
| 6 | Documentation & Usability | PASS | Fixes user-facing accuracy |
| 7 | Performance & Efficiency | PASS | N/A |
| 8 | Automation & Self-Improvement | PASS | N/A |

### Guardian Report

**Verdict:** GUARDIAN_APPROVED

**Risk Tier:** LOW — documentation-only, 0 production code lines touched

**VP-1 Independent Verification:**
- Files: declared 1 vs actual 1 — Match: YES
- Tests: N/A (documentation change)
- Scope: CLEAN

**Blast Radius Map:**
```
docs/api-reference.md --> (no importers, no runtime consumers)
Score: 0 (LOW)
```

**Anti-Pattern Scan:** #1 CLEAR | #2 CLEAR | #3 CLEAR | #4 N/A | #5 CLEAR | #6 N/A | #7 N/A | #8 CLEAR | #9 N/A

**Confidence:** HIGH

---

## Overseer Execution (Standard Mode)

### Mode: STANDARD
Execute: Phase 0, 1, 2, 2.5 (N/A — not Type B for code endpoint), 3, 6.
Skip: Phase 4, 5, 5.5, 5.7, 7.

### Phase 1: Requirement Decomposition

| # | Requirement | Source |
|---|-------------|--------|
| 1 | API endpoint path updated from v1 to v2 | user words |
| 2 | Curl example updated to match | implied |

### Phase 3: Drift Detection

- Scope creep: none
- Under-delivery: none
- Misinterpretation: none
- Behavioral drift: none

### Overseer Report (Standard)

**Verdict:** OVERSEER_APPROVED
**Mode:** STANDARD
**Aggregate confidence:** 95% — **Result:** PASS

---

## PM-Admin Execution (Standard Mode)

### Mode: STANDARD
Execute: Phase 0 (bochi + memory state), Phase 1 (scope), Phase 4 (runtime + Type B).
Skip: Phase 2, 3, 5.

### Phase 0: bochi Memory Loading

```
bochi 記憶状態:
- index.jsonl: [LOADED/UNAVAILABLE]
- user-profile.yaml pm_admin: [LOADED/UNAVAILABLE]
- Referenced records: N/A (simple doc fix)
```

### Phase 1: Scope Compliance

Scope compliance: PASS — documentation-only change within declared boundary.

### Phase 4: Runtime Verification

```bash
# Verify endpoint matches source
$ grep -rn "v2/users" src/routes/users.ts
12:  router.post('/api/v2/users', createUserHandler);
```

Runtime verification: PASS — documentation matches actual endpoint.

### PM-Admin Report (Standard)

**Verdict:** YES
**Mode:** STANDARD
**4-Axis Review (Standard — Axis 1 + 4 only):**
| Axis | Result | Evidence |
|------|--------|----------|
| 1. Scope Compliance | PASS | docs/ only, within boundary |
| 4. Runtime Verification | PASS | grep confirms endpoint path |

---

## Verification Assertions

Grep-testable patterns to validate this scenario file:

```bash
# 1. Writer report uses correct XML tags
grep -c "<writer_report>" scenario-s-small-change.md   # expected: 1
grep -c "</writer_report>" scenario-s-small-change.md  # expected: 1

# 2. Guardian outputs Risk Tier: LOW
grep -c "Risk Tier: LOW" scenario-s-small-change.md    # expected: 2

# 3. Evidence-of-Execution present (Bash output examples)
grep -c '^\$' scenario-s-small-change.md               # expected: ≥4

# 4. Anti-Pattern #1 (Spec-as-Done) checked as CLEAR
grep "Spec-as-Done: CLEAR" scenario-s-small-change.md  # expected: 1 match

# 5. Standard-tier flow declared
grep "Writer + Guardian" scenario-s-small-change.md    # expected: ≥1
grep "Overseer.*standard" scenario-s-small-change.md   # expected: ≥1
grep "PM-Admin.*standard\|PM-Admin.*Standard" scenario-s-small-change.md  # expected: ≥1

# 6. Guardian verdict is APPROVED
grep "GUARDIAN_APPROVED" scenario-s-small-change.md    # expected: 1

# 7. 8-axis evaluation present with all PASS
grep -c "| PASS |" scenario-s-small-change.md          # expected: 8
```
