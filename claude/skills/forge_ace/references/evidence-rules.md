# Evidence-of-Execution Rules (shared across all agents)

## Gate Rule

No agent may output APPROVED/YES without ALL of:
1. Code execution evidence (Bash output or test results)
2. File existence evidence (Read/Grep result with file:line)
3. Evidence from the SAME session (not stale)

## Prohibited Claim Phrases

These are claims, NOT evidence:
- "exists" / "wrote" / "should pass" / "documented"
- "Tests written" / "Code is correct" / "Other agents said PASS"

## Required Evidence Format

```
Executed `npm test` -> output: 12 passed, 0 failed
Grep found `functionName` at src/utils.ts:42
Read /tmp/output.json -> contains expected field
```

## Per-Agent Application

| Agent | Evidence Required |
|-------|------------------|
| Writer | Bash test output after implementation |
| Guardian | Independent test re-run (not Writer's claim) |
| Overseer | Test PASS output per requirement claim |
| PM-Admin | Independent Bash execution (not other agents' claims) |
| Designer | Screenshot captured AND Read tool inspected image |

## Circuit Breaker (Guardian)

- Round 1: Provide specific, actionable fixes
- Round 2 same issues: Provide exact code patches
- Round 3: HARD STOP -> GUARDIAN_ESCALATE -> human decides
