# Type B Change Verification Gates

## Classification Heuristic

```
Type A: ALL changed files are executable code (.ts/.js/.py/.go/.rs/.java/etc.)
  -> Standard flow: tests verify behavior

Type B: ANY changed file is spec/prompt/config (.md prompts, SKILL.md, YAML/JSON config, HARD-GATE definitions)
  -> Additional gates required (below)
```

## Gate 1: Reproduce-Before-Fix

BEFORE applying any spec change, demonstrate the bug/behavior EXISTS:
```
Target file: ___
Bug/behavior to fix: ___
Reproduction evidence: [Bash output or scenario log]
```
If reproduction fails -> STOP. Cannot fix what cannot be reproduced.

## Gate 2: Delta Demonstration

AFTER applying the fix, show before vs after:
```
Before-behavior: [reproduction evidence from Gate 1]
After-behavior: [same scenario re-executed AFTER fix]
Behavioral delta: [specific difference observed]
```
"File content changed" is NOT a delta. "Behavior X became behavior Y" IS a delta.

## Gate 3: E2E Behavioral Verification

After all agents approve, orchestrator runs actual scenario:
```
E2E SCENARIO (Type B):
1. Trigger: [how to invoke the changed spec/prompt/config]
2. Expected behavior: [what should happen if the fix works]
3. Failure indicator: [what would indicate the fix did NOT work]
```
Scenario PASS = ship. FAIL = reject (even if all agents said APPROVED).

## Agent Responsibilities for Type B

| Agent | Type B Duty |
|-------|-------------|
| Writer | Execute Gate 1 + Gate 2, provide evidence |
| Guardian | Verify Writer evidence present; flag "structural review cannot verify behavioral compliance" |
| Overseer | Assess delta convincingness; define E2E scenario (Gate 3) |
| PM-Admin | Verify full Type B chain complete; issue E2E Execution Mandate |
