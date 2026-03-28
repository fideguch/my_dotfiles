---
name: triple-agent-coding
description: 3-agent gate workflow (Writer/Guardian/Overseer) for safely modifying existing code. Use when changing 3+ files in a running system.
---

# Triple Agent Coding

Safely modify existing code with a 3-agent sequential gate: Writer implements, Guardian verifies structural safety, Overseer confirms requirements alignment. One change-set at a time, no gate skipping.

**Origin:** bochi v2.5 deploy regression — a working bot's permissions broke because changes were made without full structural understanding. This skill prevents that class of failure.

**Core principle:** Writer proposes → Guardian proves safety → Overseer confirms intent. All three must pass before proceeding.

## When to Use

- Modifying 3+ files in a single change
- Touching a running/deployed system
- Applying user feedback that affects multiple components
- Any change where "it was working before" matters

**Do NOT use for:**
- 1-2 file edits with clear scope (use normal code-reviewer)
- Greenfield features with no existing code at risk (use subagent-driven-development)
- Documentation-only changes

## The 3 Roles

### Writer (Implementer)

Writes the code change. One logical change-set at a time.

- **Agent:** `subagent_type=general-purpose`, `isolation=worktree`
- **Model:** Standard (Sonnet). Upgrade to Opus for multi-file integration
- **Scope:** Implement exactly what was requested, nothing more
- **Output:** Changed files + self-review report

### Guardian (Structural Safety Verifier)

Reads the ENTIRE relevant codebase BEFORE reviewing. Does not skim — traces every import, type definition, config reference, and test dependency to build a complete mental model. Asks "why is this written this way?" for every non-obvious pattern, and follows references until the answer is found.

- **Agent:** `subagent_type=general-purpose` (needs Read + Grep + Glob for deep tracing)
- **Model:** Opus (requires deepest reasoning for structural analysis)
- **Scope:** Prove that the change breaks nothing. Verify every touchpoint.
- **Gate:** Must explicitly approve (`GUARDIAN_APPROVED`) before Overseer runs

**Guardian's deep-trace protocol:**
1. Read all files changed by Writer
2. For each changed file: trace ALL imports, exported symbols, type references
3. For each dependency found: read it, understand its contract, verify the change respects it
4. For config/env references: verify values exist and are correct in all environments
5. For test files: verify tests still cover the changed behavior
6. For any pattern that is not self-evident: ask "why?" and trace until answered
7. Build a dependency map of the change's blast radius
8. Only then: judge whether the change is safe

### Overseer (Requirements Alignment Verifier)

Verifies that what was built matches what the user actually asked for. Catches spec drift, scope creep, and misinterpretation.

- **Agent:** `subagent_type=architect`
- **Model:** Opus (needs judgment for intent matching)
- **Scope:** Compare user's original request against actual implementation
- **Gate:** Must explicitly approve (`OVERSEER_APPROVED`) before proceeding

## Sequential Gate Flow

```
User requirement
  |
  v
[Writer] implements change-set (worktree-isolated)
  |
  v
[Guardian] deep-traces entire blast radius
  |--- GUARDIAN_REJECTED (with specific reasons) --> Writer fixes --> Guardian re-reviews
  |--- Max 3 rounds --> ESCALATE to human
  |
  v (GUARDIAN_APPROVED)
[Overseer] verifies requirement alignment
  |--- OVERSEER_REJECTED (requirement drift detected) --> Writer adjusts --> full re-review
  |--- Max 3 rounds --> ESCALATE to human
  |
  v (OVERSEER_APPROVED)
Next change-set (or done)
```

**Hard rules:**
- Guardian NEVER runs before Writer completes
- Overseer NEVER runs before Guardian approves
- Writer NEVER proceeds to next change-set before Overseer approves
- Maximum 3 rejection rounds per gate before human escalation
- Each agent gets fresh context (no inherited session state)

## How to Execute

### Step 0: Preparation

```
1. Identify the requirement (user request, bug report, feedback)
2. Break the change into logical change-sets (1-3 files each)
3. Order change-sets by dependency (foundations first)
4. For each change-set, note which files will be modified
```

### Step 1: Dispatch Writer

Use `./writer-prompt.md` template. Provide:
- The specific change-set to implement
- Full requirement text
- Working directory
- Any constraints or patterns to follow

Writer works in `isolation: worktree` and reports back with:
- Status (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT)
- Files changed
- Self-review findings

### Step 2: Dispatch Guardian

Use `./guardian-prompt.md` template. Provide:
- Files changed by Writer (list only — Guardian reads them independently)
- The original requirement (for context, not for spec checking)
- The project's root directory

Guardian deep-traces and reports:
- `GUARDIAN_APPROVED` — change is structurally safe
- `GUARDIAN_REJECTED` — with specific breakage risks and evidence

**If rejected:** Re-dispatch Writer with Guardian's findings. Then re-dispatch Guardian.

### Step 3: Dispatch Overseer

Use `./overseer-prompt.md` template. Provide:
- The user's original requirement (exact words)
- Writer's report of what was implemented
- Guardian's approval summary

Overseer reports:
- `OVERSEER_APPROVED` — implementation matches user intent
- `OVERSEER_REJECTED` — with specific drift/gap analysis

**If rejected:** Re-dispatch Writer with Overseer's feedback. Re-run BOTH Guardian and Overseer.

### Step 4: Proceed or Finish

If more change-sets remain, return to Step 1.
If all change-sets complete, merge worktree and commit.

## Prompt Templates

- `./writer-prompt.md` — Dispatch Writer subagent
- `./guardian-prompt.md` — Dispatch Guardian subagent (deep-trace protocol)
- `./overseer-prompt.md` — Dispatch Overseer subagent (requirement alignment)

## Model Selection

| Role | Default Model | Upgrade When |
|------|--------------|--------------|
| Writer | Sonnet | Multi-file integration, complex refactoring |
| Guardian | Opus | Always Opus (structural reasoning is critical) |
| Overseer | Opus | Always Opus (intent judgment is critical) |

## Red Flags

**Never:**
- Skip Guardian gate (even for "small" changes — that's how regressions happen)
- Let Guardian skim instead of deep-trace (the whole point is exhaustive verification)
- Run Guardian and Overseer in parallel (Overseer needs Guardian's safety confirmation)
- Accept Guardian approval without specific evidence (must cite files read and contracts verified)
- Let Writer modify files outside the declared change-set scope
- Proceed past 3 rejection rounds without human input
- Trust Writer's self-review as a substitute for Guardian review

**Escalation triggers:**
- Guardian finds a change that affects authentication, billing, or data integrity
- Overseer detects the implementation solves a different problem than requested
- Writer reports BLOCKED on the same issue twice
- Any agent's output contradicts another agent's findings

## vs. Other Skills

| Skill | Use When |
|-------|----------|
| **triple-agent-coding** | Modifying existing running code, safety-critical changes |
| **subagent-driven-development** | Executing a plan with independent tasks (greenfield-friendly) |
| **dispatching-parallel-agents** | Independent problems that don't share state |
| **code-review** | Post-implementation review (single pass, no gate) |

## Integration

**Works with:**
- **using-git-worktrees** — Writer operates in isolated worktree
- **finishing-a-development-branch** — After all change-sets complete
- **test-driven-development** — Writer follows TDD within each change-set

**Does NOT replace:**
- Final code-reviewer pass (run after all change-sets merge)
- Security review (run separately for auth/billing changes)
