# forge_ace Anti-Patterns Reference Card

9 structural failure patterns detected across all forge_ace agents.
Each agent's Anti-Patterns section references this file for full definitions.

## Anti-Patterns (HARD-GATE — detect and act)

### 1. Spec-as-Done Illusion
Writing a spec/README and treating it as "implemented."
A spec file is NOT evidence of working code.
**Detection**: Agent report cites spec/doc as proof of implementation.
**Action**: Require Bash execution evidence showing the spec'd behavior actually works.

### 2. Phantom Addition Fallacy
Planning to "add" something that already exists.
**Detection**: Plan says "create" or "add" without first reading the target file.
**Action**: Read the file first. Prove absence before creation. Label steps CREATE/MODIFY.

### 3. Delegated Verification Deficit
Trusting subagent or tool reports without independent verification.
**Detection**: Agent cites another agent's claim as sole evidence.
**Action**: VP-1 — verify independently with Bash/Read/Grep. "They said PASS" ≠ evidence.

### 4. Delta Thinking Trap
Estimating quality as "+N points" instead of full rubric re-evaluation.
**Detection**: Score justification references deltas rather than absolute measurements.
**Action**: VP-2 — blind re-evaluation of ALL rubric items before viewing prior scores.

### 5. Stale Context Divergence
Using old line numbers, outdated memory records, or stale file state.
**Detection**: Agent references specific line numbers from earlier in the session.
**Action**: Re-read files before referencing. Use content anchors, not line numbers.

### 6. Spec-without-Implementation-Table
Creating a spec that references external components (CLI, cron, hook, API, DB migration,
env vars) without appending an Implementation Status table (✅/❌).
**Detection**: Spec file mentions external dependencies but no status table at bottom.
**Action**: Append `## Implementation Status` table. Any ❌ = "not implemented."

### 7. Precondition-as-Assumption
Test descriptions containing "(with X present)", "(assuming Y)", "(after Z)" —
hidden preconditions that are not independently tested.
**Detection**: Grep test descriptions for "(with", "(assuming", "(after" patterns.
**Action**: Extract each precondition as an independent test. Precondition FAIL → dependent tests SKIP (not PASS).

### 8. High-Risk-Implementation-Gap
Session-external work referenced without user confirmation. Claude's known weak spots:
- cron / launchd / systemd (session-external scheduling)
- SSH server configuration (may be unreachable)
- OAuth / browser auth flows (Claude cannot operate browsers)
- Production environment variables (.env.production)
- DNS / SSL certificates / CI-CD pipeline configuration
**Detection**: Task content matches above patterns.
**Action**: Output `⚠️ HIGH RISK PATTERN: [name]`. Do NOT proceed without user confirmation.

### 9. Disconnected-Bloodline
Code references external server/API/DB connections but reachability is not verified.
Markdown config ≠ live connection.
**Detection**: Code contains SSH/HTTP/DB/S3/MQ/WS connection patterns.
**Action**: Run reachability test (ssh/curl/aws CLI). Output = evidence. No output = no approval.
Guardian Phase 2.7 performs systematic detection and verification.
