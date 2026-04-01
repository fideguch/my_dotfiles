# forge_ace v4.0 — 5-Agent Quality Gate

5-agent gate workflow (Writer/Guardian/Overseer/PM-Admin/Designer) for safely modifying existing code and UI with PDCA-driven quality assurance.

## When to Use

- Changes span requirements -> design -> implementation
- UI/UX changes need design quality verification
- PM-level scope delegation ("全部任せる" / "ここまで作って" / "設計だけ見て")
- Code-only without UI: Standard tier (Writer + Guardian + Overseer-std + PM-Admin-std)

## Step 1: Session Initialize

<step id="init">

1. Write `/tmp/.forge-ace-session.json`:
   ```json
   {"version":"4.0","created":"[ISO]","tier":null,"type":null,"state":"INIT","checkpoint_filled":false,"user_confirmed":false,"agents":{"writer":{"status":"pending","verdict":null},"guardian":{"status":"pending","verdict":null},"overseer":{"status":"pending","verdict":null},"pm_admin":{"status":"pending","verdict":null},"designer":{"status":"pending","verdict":null}},"transitions":[]}
   ```
2. Classify change target: Type A (all code) or Type B (any spec/prompt/config)
   - Reference: `references/type-b-gates.md`
3. Classify tier: Standard (no UI) or Full (UI present or user specifies)
4. Update session: `state -> CLASSIFIED, tier -> X, type -> X`
5. Feature Prerequisites — verify referenced files/tools exist:
   ```bash
   ls [referenced_config_files] && which [referenced_CLI_tools]
   ```
   Any MISSING -> WARNING + user confirmation before proceeding.

</step>

## Step 2: Dispatch Checkpoint

<step id="checkpoint">

Fill ALL blanks. Empty blanks = visible violation. Hooks enforce this.

```
Tier: ___
Type: ___
Root: ___

Agent composition:
- [ ] Writer: ___
- [ ] Guardian: ___
- [ ] Overseer (___): ___
- [ ] PM-Admin (___): ___
- [ ] Designer: ___

Deviation: ___
```

1. Update session: `checkpoint_filled -> true`
2. Present to user. Wait for confirmation.
3. Update session: `user_confirmed -> true, state -> USER_CONFIRMED`

</step>

## Step 3: Plan Quality Gate

<step id="pqg">

Dispatch planner agent to validate implementation plan:
```
Agent tool (planner):
  description: "Plan Quality Gate: validate implementation plan"
  model: opus
  prompt: |
    Follow ~/.claude/agents/planner.md v2.0 protocol.
    Request: [user's original requirement]
    Tier: [Standard or Full]
    Project root: [path]
    Execute: Tier confirm -> Research -> Plan -> GAFA Gate -> Output
```

Gate: All PASS -> Writer dispatch. Any FAIL -> planner revises (max 2), then human decides.
Evidence carry-forward: Research Summary + Gate Results -> Writer (context) + Guardian (verification).

</step>

## Step 4: Writer

<step id="writer">

```
Agent tool (general-purpose, isolation: worktree):
  description: "Write change-set N: [name]"
  prompt: [Load writer-prompt.md, fill template variables]
```

Update session: `state -> WRITER_DISPATCHED`
On return: `agents.writer.verdict -> X, state -> WRITER_DONE`

</step>

## Step 5: Guardian

<step id="guardian">

```
Agent tool (general-purpose):
  description: "Guardian: verify structural safety of change-set N"
  model: opus
  prompt: [Load guardian-prompt.md, paste Writer's report]
```

Update session: `state -> GUARDIAN_DISPATCHED`
On return: `agents.guardian.verdict -> X, state -> GUARDIAN_DONE`

</step>

## Step 6: Overseer

<step id="overseer">

```
Agent tool (architect):
  description: "Overseer: verify requirement alignment for change-set N"
  model: opus
  prompt: [Load overseer-prompt.md, paste Writer + Guardian reports]
```

Update session: `state -> OVERSEER_DISPATCHED`
On return: `agents.overseer.verdict -> X, state -> OVERSEER_DONE`

</step>

## Step 7: PM-Admin

<step id="pm-admin">

```
Agent tool (general-purpose):
  description: "PM-Admin: requirements quality review for change-set N"
  model: opus
  prompt: [Load pm-admin-prompt.md, paste all preceding reports]
```

Update session: `state -> PM_ADMIN_DISPATCHED`
On return: `agents.pm_admin.verdict -> X, state -> PM_ADMIN_DONE`

</step>

## Step 8: Designer (Full tier only)

<step id="designer">

```
Agent tool (general-purpose):
  description: "Designer: UI/UX quality review for change-set N"
  prompt: [Load designer-prompt.md, provide target URLs]
```

Update session: `state -> DESIGNER_DISPATCHED`
On return: `agents.designer.verdict -> X, state -> DESIGNER_DONE`

</step>

## Step 9: Complete

<step id="complete">

1. Update session: `state -> COMPLETE`
2. Display final verdict summary from all agents.
3. If Type B: execute E2E Mandate scenario from PM-Admin.
   Scenario PASS -> ship. FAIL -> reject despite agent approvals.

</step>

---

## Session Types

```
Standard: Writer -> Guardian -> Overseer(standard) -> PM-Admin(standard) -> DONE
Full:     Writer -> Guardian -> Overseer(full) -> PM-Admin(full) || Designer -> PM-Admin final -> DONE
```

Session type decision:
- Code + UI -> Coding Session (Full, Designer parallel)
- Code only -> Coding Session (Standard/Full by classifier)
- UI/UX only -> Design Session: PM-Admin -> Designer -> mutual review -> DONE

## Agents

| Agent | File | Model | Role |
|-------|------|-------|------|
| Writer | writer-prompt.md | Sonnet (Opus for multi-file) | TDD, Red Team, Evidence-of-Execution |
| Guardian | guardian-prompt.md | Opus | Blast radius, Risk-tier, 8-axis eval |
| Overseer | overseer-prompt.md | Opus | Requirements alignment, Drift detection |
| PM-Admin | pm-admin-prompt.md | Opus | Scope delegation, bochi matching, 4-axis |
| Designer | designer-prompt.md | Sonnet (Opus for complex UX) | Screenshots, 25-item QA, Visual judgment |

## Quality Standards

Evaluation uses `quality-standards.md` (symlink -> `bochi-data/master-quality-review.md`).
8-axis rubric: Design, Functionality, Complexity, Testing, Security, Docs, Performance, Automation.
Ship-ready: 70/80 (87.5%). CRITICAL: 0 | HIGH: 0 required.

## Anti-Patterns

Reference: See `anti-patterns.md` for the full 12-pattern card.

## Known Limitations (v4.0)

- `checkpoint_filled` is verified by SKILL.md protocol only, not by the dispatch hook.
  The hook checks `state` only. A future Phase 4 enhancement can add `checkpoint_filled`
  + `user_confirmed` verification to the hook for stricter enforcement.

## References

- `references/origin-and-sources.md` — Mission, research, token estimates, troubleshooting
- `references/evidence-rules.md` — Evidence-of-Execution shared rules
- `references/type-b-gates.md` — Type B change verification gates
- `anti-patterns.md` — 12 anti-patterns reference card
- `quality-standards.md` -> `bochi-data/master-quality-review.md`

## File Structure

```
~/.claude/skills/forge_ace/
├── SKILL.md                  <- This file (orchestration)
├── anti-patterns.md          <- 12 patterns reference card
├── quality-standards.md      <- symlink -> ../../bochi-data/master-quality-review.md
├── writer-prompt.md          <- v4.0
├── guardian-prompt.md        <- v4.0
├── overseer-prompt.md        <- v4.0
├── pm-admin-prompt.md        <- v4.0
├── designer-prompt.md        <- v4.0
├── references/
│   ├── origin-and-sources.md <- Mission, research, token estimates
│   ├── evidence-rules.md     <- Evidence-of-Execution shared rules
│   └── type-b-gates.md       <- Type B change verification gates
├── checklists/
│   ├── ai-defect-scan.md     <- Guardian Phase 2.5
│   └── connectivity-check.md <- Guardian Phase 2.7
└── test-scenarios/
    ├── scenario-s-small-change.md
    ├── scenario-m-api-change.md
    └── scenario-l-fullstack-with-ui.md
```
