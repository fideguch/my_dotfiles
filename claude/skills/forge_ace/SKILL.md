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
   {"version":"4.1","created":"[ISO]","tier":null,"type":null,"state":"INIT","checkpoint_filled":false,"user_confirmed":false,"qa_questions":[],"qa_answers":[],"agents":{"writer":{"status":"pending","verdict":null},"guardian":{"status":"pending","verdict":null},"overseer":{"status":"pending","verdict":null},"pm_admin":{"status":"pending","verdict":null},"designer":{"status":"pending","verdict":null}},"transitions":[]}
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
    Follow ~/.claude/agents/planner.md v2.1 protocol.
    Request: [user's original requirement]
    Tier: [Standard or Full]
    Type: [A or B]
    Project root: [path]
    Execute: Tier confirm -> Research -> Plan -> GAFA Gate -> Output
    If Type B: execute references/type-b-pqg.md checklist (SSOT/Reference/Count/Version/Terminology)
```

Gate: All PASS -> Writer dispatch. Any FAIL -> planner revises (max 2), then human decides.
Evidence carry-forward: Research Summary + Gate Results -> Writer (context) + Guardian (verification).
Type B carry-forward: SSOT map + reference list -> Writer + Guardian.

</step>

## Step 4: Writer

<step id="writer">

Dispatch isolation depends on change type:
- Type A (code): `isolation: worktree` — safe rollback via worktree discard
- Type B (spec/prompt/config): no isolation — direct edit, worktree overhead unnecessary

```
# Type A
Agent tool (general-purpose, isolation: worktree):
  description: "Write change-set N: [name]"
  prompt: [Load writer-prompt.md, fill template variables]

# Type B
Agent tool (general-purpose):
  description: "Write change-set N: [name]"
  prompt: [Load writer-prompt.md, fill template variables]
```

Update session: `state -> WRITER_DISPATCHED`
On return: `agents.writer.verdict -> X, state -> WRITER_DONE`

</step>

## Step 4.5: Q&A Loop (optional)

<step id="qa-loop">

If Writer output raises unresolved questions about requirements:

1. Update session: `state -> QA_LOOP`
2. Present questions to user (one by one, with options if applicable)
3. Record in session: `qa_questions[]` and `qa_answers[]`
4. Re-dispatch Writer with Q&A answers as additional context
5. Update session: `state -> WRITER_REVISION -> WRITER_DONE`

Skip condition: Writer status is DONE with no open questions.

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

## Step 8: Designer (Full tier, or Type B with UI specs)

<step id="designer">

Dispatch conditions:
- Full tier (any type): always dispatch — screenshot-based visual QA
- Type B + UI brief/DESIGN.md included in change: dispatch in **Type B UI spec mode**
  (review Mermaid diagrams, screen lists, component design — no screenshots needed)
- Type B without UI specs: skip Designer

```
# Full tier (screenshot mode)
Agent tool (general-purpose):
  description: "Designer: UI/UX quality review for change-set N"
  prompt: [Load designer-prompt.md, provide target URLs]

# Type B + UI spec mode
Agent tool (general-purpose):
  description: "Designer: UI spec review for change-set N"
  prompt: [Load designer-prompt.md, set mode=type-b-ui-spec, provide changed UI spec files]
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
- Type B + UI brief/DESIGN.md -> Standard + Designer (Type B UI spec mode)
- Type B without UI -> Standard (Designer skip)

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
- `references/type-b-pqg.md` — Type B Plan Quality Gate checklist
- `anti-patterns.md` — 12 anti-patterns reference card
- `quality-standards.md` -> `bochi-data/master-quality-review.md`

## File Structure

```
~/.claude/skills/forge_ace/
├── README.md                 <- Japanese documentation
├── README.en.md              <- English documentation
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
│   ├── type-b-gates.md       <- Type B change verification gates
│   └── type-b-pqg.md        <- Type B Plan Quality Gate checklist
├── checklists/
│   ├── ai-defect-scan.md     <- Guardian Phase 2.5
│   ├── connectivity-check.md <- Guardian Phase 2.7
│   └── cross-document-integrity.md <- Guardian Phase 2 Type B
├── tests/
│   ├── test-dispatch-guard.sh    <- Dispatch guard hook tests (14 cases)
│   └── test-state-machine.sh     <- State machine + session-complete tests (12 cases)
└── test-scenarios/
    ├── scenario-s-small-change.md
    ├── scenario-m-api-change.md
    ├── scenario-m-type-b-spec-fix.md
    └── scenario-l-fullstack-with-ui.md
```
