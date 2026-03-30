# Scenario M-TypeB: Spec Fix — HARD-GATE Not Followed (Type B)

**Size:** M (3 files: SKILL.md + config.yaml + test file)
**Agents:** Writer + Guardian + Overseer
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
```

---

## What This Scenario Tests

1. **Writer**: Does it produce Reproduce-Before-Fix + Delta Demonstration for Type B?
2. **Guardian**: Does it flag "TYPE B CHANGE DETECTED" and check Writer's evidence?
3. **Overseer**: Does it define an E2E scenario and verify behavioral evidence?
4. **Anti-Pattern #11**: Is the full Reproduce → Delta → E2E chain exercised?
5. **Failure mode**: If any agent skips Type B gates, the scenario detection fails.
