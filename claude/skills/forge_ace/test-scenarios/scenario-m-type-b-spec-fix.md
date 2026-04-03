# Scenario M-TypeB: Spec Fix — HARD-GATE Not Followed (Type B)

**Tier:** Standard (3 files: SKILL.md + config.yaml + test file)
**Agents:** Writer + Guardian + Overseer(standard) + PM-Admin(standard)
**Change Target:** Type B (SKILL.md + config YAML)
**Anti-Pattern #11 exercise:** Full Reproduce → Delta → E2E chain
**Source:** bochi v2.6 incident (3 spec modifications, all failed E2E)

---

## Scenario Context

A Discord bot's SKILL.md has a HARD-GATE: "all messages MUST be saved to seen.jsonl."
The bot is NOT saving messages — seen.jsonl has 0 new lines after 24 hours of operation.
Task: fix the SKILL.md so the bot actually saves messages.

**This is a Type B change.** The "fix" targets a spec file, not executable code.

---

## Expected Writer Report (Type B flow)

### Phase 0b-TypeB: Change Target Classification

```
Classification: Type B (SKILL.md is a spec/prompt file)
```

### Phase 0b-TypeB: Reproduce-Before-Fix

```
REPRODUCE-BEFORE-FIX (Type B only):
Target file: skills/bochi/SKILL.md
Bug/behavior to fix: Messages not saved to seen.jsonl despite HARD-GATE
Reproduction evidence:
  $ ssh lightsail "wc -l ~/bochi-data/seen.jsonl"
  42 /home/ubuntu/bochi-data/seen.jsonl
  $ # Send test message via Discord
  $ ssh lightsail "wc -l ~/bochi-data/seen.jsonl"
  42 /home/ubuntu/bochi-data/seen.jsonl
  → Line count unchanged after message. Bug confirmed.
```

### Phase 2: Implementation

```
File: skills/bochi/SKILL.md
BEFORE: HARD-GATE says "MUST save to seen.jsonl" (prohibition-style)
AFTER: Template-based instruction with fill-in output section:
  "After processing any message, output:
   SEEN_LOG: { message_id: [id], timestamp: [ts], saved: true }"
DELTA: Changed from prohibition to template (LLM follows templates > prohibitions)
```

### Type B Delta Demonstration

```
DELTA DEMONSTRATION:
Before-behavior: wc -l seen.jsonl = 42 (no change after message)
After-behavior:
  $ # Restart bot with new SKILL.md
  $ # Send test message via Discord
  $ ssh lightsail "wc -l ~/bochi-data/seen.jsonl"
  43 /home/ubuntu/bochi-data/seen.jsonl
  $ ssh lightsail "tail -1 ~/bochi-data/seen.jsonl"
  {"message_id":"123456","timestamp":"2026-03-30T15:00:00Z","saved":true}
Behavioral delta: seen.jsonl gained 1 line with correct format
```

### Anti-Pattern Scan

```
- Spec-Layer Blindness: Type B: reproduce=[wc -l before=42], delta=[wc -l after=43]
```

---

## Expected Guardian Report (Type B flow)

### Risk Tier + Change Target

```
Risk Tier: MEDIUM — spec change affecting bot behavior
Change Target: Type B — skills/bochi/SKILL.md, config.yaml

⚠️ TYPE B CHANGE DETECTED: [SKILL.md, config.yaml]
Structural review (blast radius, tests, 8-axis) CANNOT verify
that the target system will behaviorally comply with this spec change.
Guardian can verify: syntax, consistency, no contradictions.
Guardian CANNOT verify: LLM/system will follow this instruction.
Required: Writer's Reproduce-Before-Fix + Delta Demonstration evidence.
```

### Type B Verification

```
Type B Verification:
  Reproduce: PRESENT (wc -l before/after message = no change)
  Delta: PRESENT (wc -l 42→43, tail shows correct JSON)
```

---

## Expected Overseer Report (Type B flow)

### Phase 2.5: Type B Behavioral Verification

```
Change target: Type B
Reproduce-Before-Fix: PRESENT — convincing (line count unchanged = bug confirmed)
Delta Demonstration: PRESENT — convincing (line count +1, JSON format correct)
```

### E2E Scenario

```
E2E SCENARIO (Type B):
1. Trigger: Send Discord message "test-e2e-type-b" to bot
2. Expected behavior: seen.jsonl gains exactly 1 line within 30 seconds
3. Failure indicator: seen.jsonl line count unchanged after 60 seconds
```

---

## v4.0 State Transitions

Standard tier (Type B) — 13-step sequence, no Designer:

| Step | State Before | Action | State After |
|------|-------------|--------|------------|
| 1 | — | Session init | INIT |
| 2 | INIT | Classify (Type B detected) | CLASSIFIED |
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

### Type B Notes

- **Reproduce-Before-Fix**: Writer must demonstrate the bug exists BEFORE applying the fix (step 6)
- **Delta Demonstration**: Writer must show before vs after behavioral difference (step 6)
- **E2E Mandate**: PM-Admin issues E2E Execution Mandate at step 12; Orchestrator runs it after COMPLETE

### v4.0 Assertions

- Session `type` field set to `"B"` at step 2
- Dispatch guard blocks Writer before `USER_CONFIRMED`
- Writer report includes `REPRODUCE-BEFORE-FIX` and `DELTA DEMONSTRATION` sections
- Guardian flags `TYPE B CHANGE DETECTED`
- Overseer defines `E2E SCENARIO (Type B)`
- PM-Admin issues `E2E EXECUTION MANDATE`
- Session-complete hook writes `completed: true` to outcomes.jsonl at COMPLETE

## Verification Assertions (grep-testable)

```bash
# Writer produced Type B sections
grep -c "REPRODUCE-BEFORE-FIX" writer-report.md   # ≥ 1
grep -c "DELTA DEMONSTRATION" writer-report.md     # ≥ 1
grep -c "Type B" writer-report.md                  # ≥ 2

# Guardian flagged Type B
grep -c "TYPE B CHANGE DETECTED" guardian-report.md # ≥ 1
grep -c "Type B Verification" guardian-report.md    # ≥ 1

# Overseer defined E2E scenario
grep -c "E2E SCENARIO" overseer-report.md           # ≥ 1
grep -c "Phase 2.5" overseer-report.md              # ≥ 1

# Anti-Pattern scan includes #11
grep -c "#1-#12" guardian-report.md                  # ≥ 1

# v4.0 state transitions
grep -q "v4.0 State Transitions" scenario-m-type-b-spec-fix.md && echo "PASS: v4.0 transitions"
grep -q "Reproduce-Before-Fix" scenario-m-type-b-spec-fix.md && echo "PASS: Type B reproduce note"
grep -q "E2E Mandate" scenario-m-type-b-spec-fix.md && echo "PASS: Type B E2E mandate"
grep -q "COMPLETE" scenario-m-type-b-spec-fix.md && echo "PASS: COMPLETE state"
```

---

## What This Scenario Tests

1. **Writer**: Does it produce Reproduce-Before-Fix + Delta Demonstration for Type B?
2. **Writer**: Is it dispatched WITHOUT worktree isolation (M1: Type B no worktree)?
3. **PQG**: Does it execute Type B PQG checklist (M2: SSOT/Reference/Count/Version/Terminology)?
4. **Guardian**: Does it flag "TYPE B CHANGE DETECTED" and check Writer's evidence?
5. **Guardian**: Does it run cross-document-integrity.md instead of blast radius (M5)?
6. **Overseer**: Does it define an E2E scenario and verify behavioral evidence?
7. **Overseer**: Does it run business logic contradiction detection (M6: SSOT identification)?
8. **Anti-Pattern #11**: Is the full Reproduce -> Delta -> E2E chain exercised?
9. **Q&A Loop**: If Writer raises questions, does state transition to QA_LOOP (M4)?
10. **Failure mode**: If any agent skips Type B gates, the scenario detection fails.

## v4.1 Additions (M1-M6)

### M1: Writer dispatched without worktree for Type B
```bash
# Verify Writer dispatch does NOT include "isolation: worktree"
grep -c "isolation.*worktree" writer-dispatch-log.md  # expected: 0 for Type B
```

### M2: Type B PQG checklist executed
```bash
grep -c "SSOT Mapping" pqg-report.md           # >= 1
grep -c "Reference Integrity" pqg-report.md     # >= 1
grep -c "Count Consistency" pqg-report.md        # >= 1
```

### M4: Q&A Loop state (if applicable)
```bash
grep -c "QA_LOOP" /tmp/.forge-ace-session.json   # >= 1 if questions raised
grep -c "qa_questions" /tmp/.forge-ace-session.json  # >= 1
```

### M5: Cross-document integrity check
```bash
grep -c "Cross-Document Integrity" guardian-report.md  # >= 1
grep -c "VERSION_MISMATCH\|COUNT_MISMATCH\|SSOT_VIOLATION\|BROKEN_REFERENCE\|TERM_INCONSISTENCY" guardian-report.md
```

### M6: Business logic contradiction detection
```bash
grep -c "Business Logic Contradiction" overseer-report.md  # >= 1
grep -c "SSOT owner" overseer-report.md                     # >= 1 if contradiction found
```
