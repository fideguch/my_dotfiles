# Test Scenario: Standard-Tier — API Endpoint Addition

**Tier:** Standard (5 files, >100 lines, API surface change, no UI)
**Agents:** Writer + Guardian + Overseer(standard) + PM-Admin(standard)
**Scenario:** Add `GET /api/v1/notifications` endpoint to Express.js app

## Scenario Context

Add a notifications API endpoint that returns paginated notifications for the authenticated user.
Files: router, controller, service, model, test.

## Expected Writer Report

<writer_report>

### Status
DONE

### Before/After Specification
```
File: src/routes/api.ts
BEFORE: No /notifications route
AFTER: GET /api/v1/notifications with auth middleware, pagination (page, limit)
DELTA: New route registration + controller binding
RISK: Auth middleware must be applied; pagination edge cases
```

### Files Changed
| File | Change Type | Description |
|------|------------|-------------|
| src/routes/api.ts | MODIFY | Add notifications route |
| src/controllers/notification.controller.ts | CREATE | getNotifications handler |
| src/services/notification.service.ts | CREATE | findByUserId with pagination |
| src/models/notification.model.ts | CREATE | Notification schema + types |
| src/tests/notification.test.ts | CREATE | 8 test cases |

### Tests
- New tests written: 8 (auth, pagination, empty, invalid page, sort order, limit bounds, 404, response shape)
- Test run result: PASS (8/8)
- **Test execution evidence:**
```
$ npm test -- --testPathPattern="notification"
PASS src/tests/notification.test.ts (1.2s)
  GET /api/v1/notifications
    ✓ returns 200 with valid auth token (45ms)
    ✓ returns 401 without auth (12ms)
    ✓ paginates with page=2&limit=10 (38ms)
    ✓ returns empty array for user with no notifications (15ms)
    ✓ returns 400 for page=-1 (8ms)
    ✓ sorts by createdAt descending (22ms)
    ✓ caps limit at 100 (10ms)
    ✓ response matches NotificationResponse schema (18ms)
Tests: 8 passed, 8 total
```

### Anti-Pattern Scan
- Spec-as-Done: CLEAR (tests executed, PASS confirmed)
- Phantom Addition: CLEAR (grep confirmed no existing /notifications route)
- Spec-without-Implementation-Table: CLEAR (see below)
- Precondition-as-Assumption: CLEAR (auth tested independently)

### Implementation Status
| Component | Status | Evidence |
|-----------|--------|----------|
| Route registration | ✅ | src/routes/api.ts:42 |
| Controller | ✅ | src/controllers/notification.controller.ts:1-35 |
| Service | ✅ | src/services/notification.service.ts:1-28 |
| Model | ✅ | src/models/notification.model.ts:1-22 |
| Tests | ✅ | 8/8 PASS |

### Confidence
88%

</writer_report>

## Expected Guardian Report

**Verdict:** GUARDIAN_APPROVED

**Risk Tier:** MEDIUM — 5 files, new API surface, auth-protected endpoint

**VP-1 Independent Verification:**
- Files: declared 5 vs actual 5 — Match: YES
- Tests: declared 8 vs actual 8 — Guardian re-run: PASS (8/8)
- Scope: CLEAN

**Blast Radius Map:**
```
src/routes/api.ts --> src/app.ts (safe) [evidence: api.ts:1 import unchanged]
notification.controller --> routes/api.ts only (safe) [evidence: grep shows 1 consumer]
notification.service --> controller only (safe) [evidence: grep shows 1 consumer]
notification.model --> service only (safe) [evidence: grep shows 1 consumer]
```
Blast Radius Score: 12 (MEDIUM) — 5 files × 1 depth × 2 API-surface weight + auth sensitivity

**AI-Defect Scan:** Phantom deps: none | Preconditions: CLEAN | APIs: none | Over-eng: none | Security: CLEAR
**Quality Standards 8-Axis:** All 8 PASS
**Anti-Pattern Scan:** [#1-#12]: All CLEAR
**Confidence:** HIGH

## Expected Overseer Report

**Verdict:** OVERSEER_APPROVED
**Spec source used:** user words

**Requirements Verification Table:**
| # | Requirement | Source | Status | Confidence | Evidence |
|---|-------------|--------|--------|------------|----------|
| 1 | GET /notifications returns paginated list | user words | MET | 95% | test PASS: pagination |
| 2 | Auth required | implied | MET | 95% | test PASS: 401 without auth |
| 3 | Sort by newest first | implied | MET | 90% | test PASS: sort order |

**Aggregate confidence:** 93% — **Result:** PASS

**Drift Detection:**
- Scope creep: none
- Under-delivery: none
- Behavioral drift: none
- Vision alignment: ALIGNED

**Regression Guards:**
- Existing routes: PRESERVED (no route conflicts detected)
- Auth middleware: PRESERVED (grep shows unchanged)

## Expected PM-Admin Report (Standard Mode)

**Verdict:** YES
**Mode:** STANDARD

**bochi 記憶状態:**
- index.jsonl: [LOADED/UNAVAILABLE]
- user-profile.yaml pm_admin: [LOADED/UNAVAILABLE]
- Referenced records: N/A

**Scope Declaration:**
- Level: full
- Scope compliance: PASS

**4-Axis Review (Standard — Axis 1 + 4 only):**
| Axis | Result | Evidence |
|------|--------|----------|
| 1. Scope Compliance | PASS | 5 files within declared boundary |
| 4. Runtime Verification | PASS | npm test: 8/8 PASS |

**Cross-Agent Consistency:**
- Writer → Guardian: consistent (8/8 tests, 5 files)
- Guardian → Overseer: consistent (APPROVED)
- Independent verification: matches

## v4.0 State Transitions

Standard tier (Type A) — 13-step sequence, no Designer:

| Step | State Before | Action | State After |
|------|-------------|--------|------------|
| 1 | — | Session init | INIT |
| 2 | INIT | Classify | CLASSIFIED |
| 3 | CLASSIFIED | Fill checkpoint | CHECKPOINT_FILLED |
| 4 | CHECKPOINT_FILLED | User confirms | USER_CONFIRMED |
| 5 | USER_CONFIRMED | Dispatch Writer | WRITER_DISPATCHED |
| 6 | WRITER_DISPATCHED | Writer completes | WRITER_DONE |
| 7 | WRITER_DONE | Dispatch Guardian | GUARDIAN_DISPATCHED |
| 8 | GUARDIAN_DISPATCHED | Guardian completes | GUARDIAN_DONE |
| 9 | GUARDIAN_DONE | Dispatch Overseer | OVERSEER_DISPATCHED |
| 10 | OVERSEER_DISPATCHED | Overseer completes | OVERSEER_DONE |
| 11 | OVERSEER_DONE | Dispatch PM-Admin | PM_ADMIN_DISPATCHED |
| 12 | PM_ADMIN_DISPATCHED | PM-Admin completes | PM_ADMIN_DONE |
| 13 | PM_ADMIN_DONE | Standard: skip Designer | COMPLETE |

### v4.0 Assertions

- Session file created at step 1 with `state: INIT`
- Dispatch guard blocks Writer before `USER_CONFIRMED`
- Dispatch guard blocks Guardian before `WRITER_DONE`
- Designer steps skipped (Standard tier)
- Session-complete hook writes `completed: true` to outcomes.jsonl at COMPLETE

## Verification Assertions

```bash
# Structure
grep -q "writer_report" test-scenarios/scenario-m-api-change.md && echo "PASS: writer_report tag"
grep -q "Risk Tier: MEDIUM" test-scenarios/scenario-m-api-change.md && echo "PASS: risk tier"
grep -q "Blast Radius Score: 12" test-scenarios/scenario-m-api-change.md && echo "PASS: blast radius"
grep -q "GUARDIAN_APPROVED" test-scenarios/scenario-m-api-change.md && echo "PASS: guardian verdict"
grep -q "OVERSEER_APPROVED" test-scenarios/scenario-m-api-change.md && echo "PASS: overseer verdict"
grep -q "behavioral_drift\|Behavioral drift" test-scenarios/scenario-m-api-change.md && echo "PASS: drift check"
grep -q "Implementation Status" test-scenarios/scenario-m-api-change.md && echo "PASS: anti-pattern #6"
grep -q "npm test" test-scenarios/scenario-m-api-change.md && echo "PASS: evidence-of-execution"

# v4.0 state transitions
grep -q "v4.0 State Transitions" test-scenarios/scenario-m-api-change.md && echo "PASS: v4.0 transitions"
grep -q "COMPLETE" test-scenarios/scenario-m-api-change.md && echo "PASS: COMPLETE state"
```
