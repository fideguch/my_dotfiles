# forge_ace — 5-Agent Quality Gate Workflow

5-agent gate workflow (Writer/Guardian/Overseer/PM-Admin/Designer) for safely modifying existing code and UI with PDCA-driven quality assurance. Evolution of triple-agent-coding with requirements quality and design quality gates.

## Mission

Prevent the gap between "code works" and "the right thing was built" by adding PM-Admin (requirements quality) and Designer (UI/UX quality) to the proven Writer/Guardian/Overseer pipeline.

## Origin

- **triple-agent-coding v2.0**: 3-agent code quality gate (Writer/Guardian/Overseer)
- **Amazon 90-day reset (2026-03)**: 630M order loss from AI code without safeguards
- **bochi-data 15 lessons**: Spec-as-Done Illusion, Delegated Verification Deficit, etc.
- **12 research sources**: Anthropic, Addy Osmani (Google), Microsoft Azure, CodeRabbit, Baymard, DORA 2025

## When to Use

Use forge_ace when:
- Changes span requirements → design → implementation
- UI/UX changes need design quality verification
- PM-level scope delegation is needed ("全部任せる" / "ここまで作って" / "設計だけ見て")
- The task involves bochi-data pattern matching for judgment

For code-only changes without UI or requirements review:
- Use forge_ace Standard tier (Writer + Guardian + Overseer-standard + PM-Admin-standard)

---

## Session Types

### Coding Session (code changes)

Triggered when: code creation or modification is needed.

**Tier Classifier** determines pipeline:

```
Standard: All code/spec changes (no UI)
  → Writer + Guardian + Overseer(standard) + PM-Admin(standard)

Full: UI changes present OR user specifies "Full" / "forceFull"
  → Writer + Guardian + Overseer(full) + PM-Admin(full) + Designer
```

**Change Target Classification** (Standard/Full と直交):

```
Type A (Executable Code): .ts/.js/.py/.go/.rs/.java/etc.
  → Standard flow: tests verify behavior, Guardian traces blast radius

Type B (Spec/Prompt/Config): .md prompts, SKILL.md, YAML/JSON config,
  natural language instruction files, HARD-GATE definitions
  → Additional gates required (Type B Mandatory Gates below)

Classification heuristic:
  ALL changed files are code → Type A
  ANY changed file is spec/prompt/config → Type B (stricter gate applies)
```

**Type B Mandatory Gates** (Anti-Pattern #11 defense):

```
1. Reproduce-Before-Fix: demonstrate target bug/behavior EXISTS
   BEFORE applying spec change. Evidence = Bash output or scenario log.
2. Delta Demonstration: show before-behavior vs after-behavior.
   "File changed" ≠ evidence. "Behavior changed" = evidence.
3. E2E Behavioral Verification: after all agents approve, orchestrator
   runs actual scenario. Scenario PASS = ship. FAIL = reject
   (even if all agents said APPROVED).
```

**Overseer standard mode** (most important mission preserved: requirements alignment + drift):
  Execute: Phase 0 (context), 1 (decomposition), 2 (verification),
           2.5 (Type B if applicable), 3 (drift detection), 6 (judgment)
  Skip: Phase 4, 5, 5.5 (Guardian covers 8-axis), 5.7 (no UI), 7

**PM-Admin standard mode** (most important mission preserved: scope + runtime + bochi):
  Execute: Phase 0 (bochi + memory state), 1 (scope compliance),
           4 (runtime verification + Type B check), judgment
  Skip: Phase 2 (quality alignment detail), 3 (priority), 5 (session memory)

**HARD-GATE: Quality is size-independent.**
Even Standard tier gets Guardian's quality-standards.md 8-axis evaluation.
Tier controls agent MODE, not quality STANDARDS.

**Flow:**
```
Standard: Writer → Guardian → Overseer(standard) → PM-Admin(standard) → DONE
Full:     Writer → Guardian → Overseer(full) → PM-Admin(full) ∥ Designer → PM-Admin final → DONE
```

### Design Session (UI/UX artifacts)

Triggered when: UI/UX artifact creation or modification without code changes.

**Participants:** PM-Admin + Designer (mandatory), Writer/Guardian/Overseer (feasibility only)

**Flow:**
```
PM-Admin(requirements review) → Designer(design+QA) → mutual review → PM-Admin final → DONE
```

### Session Type Decision

```
Code change AND UI change → Coding Session (Full tier, Designer participates in parallel)
Code change only         → Coding Session (Standard/Full by classifier)
UI/UX only               → Design Session
```

---

## Feature Prerequisites Check (before agent dispatch)

After Complexity Classification, before dispatching ANY agent:

```bash
# Verify referenced files/tools exist
ls [referenced_config_files]
which [referenced_CLI_tools]
ls [referenced_directories]
ls [referenced_fixtures]
```

Any MISSING → WARNING + user confirmation before proceeding.
"Errors will be caught later" is NOT acceptable. Detect non-existence NOW.

---

## forge_ace Dispatch Checkpoint (MANDATORY)

Before dispatching ANY agent, the orchestrator MUST fill this template
and present it to the user. Empty blanks = visible violation.

```
Tier Classifier 結果: [Standard / Full]
判定根拠: [UI 変更あり → Full / UI なし → Standard]
ユーザーの明示的指定: [なし / Standard / Full / forceFull]
→ 確定 Tier: [Standard / Full]  ※ユーザー指定優先

確定 Tier のエージェント構成:
- [ ] Writer: [dispatch]
- [ ] Guardian: [dispatch]
- [ ] Overseer: [dispatch (standard) / dispatch (full)]
- [ ] PM-Admin: [dispatch (standard) / dispatch (full)]
- [ ] Designer: [dispatch / N/A (Standard)]

標準パイプラインからの逸脱: [YES: 内容 / NO]
→ YES の場合: STOP。ユーザーに選択肢を提示し承認を得る。

ユーザー確認: [PENDING — dispatch 前に必ず解決]
```

This template replaces prohibition text with mandatory procedure.
Blanks are visible when unfilled. Prohibitions are invisible when violated.

---

## Plan Quality Gate (ALL tiers)

For ALL changes, validate plan quality BEFORE dispatching agents.

**Trigger**: Tier Classifier returns Standard or Full.

**Dispatch**:
```
Agent tool (planner):
  description: "Plan Quality Gate: validate implementation plan"
  model: opus
  prompt: |
    Follow ~/.claude/agents/planner.md v2.0 protocol.
    Request: [user's original requirement]
    Tier: [Standard or Full from Classifier]
    Project root: [path]
    Execute: Tier confirm → Research → Plan → GAFA Gate → Output
```

**Status Display** (1-line to user):
```
Plan Quality: [Standard/Full], [PASS/CONDITIONAL/FAIL] — [1-line reason]
```

**Gate Decision**:
- All PASS → proceed to Writer dispatch
- Any FAIL → planner revises (max 2 iterations), then human decides
- User override: "skip-plan-gate" → bypass with WARNING logged

**Evidence Carry-Forward**:
Research Summary + Gate Results are passed to Writer (as context) and Guardian
(for verification). Overseer uses Gate Results for requirements alignment check.

**bochi-data Integration**:
Planner v2.0 automatically searches `~/.claude/bochi-data/index.jsonl` for
past judgment patterns relevant to the task (L6 in Research Hierarchy).
Results are included in the plan's Research Summary section.

---

## Agents

| Agent | File | Model | Role |
|-------|------|-------|------|
| Writer | writer-prompt.md | Sonnet (Opus for multi-file) | Implement with TDD, Red Team, Evidence-of-Execution |
| Guardian | guardian-prompt.md | Opus | Blast radius trace, Risk-tier routing, 8-axis eval, Blood vessel verification |
| Overseer | overseer-prompt.md | Opus | Requirements alignment, Behavioral drift detection, DESIGN.md verification |
| PM-Admin | pm-admin-prompt.md | Opus | Scope delegation, bochi pattern matching, 4-axis review |
| Designer | designer-prompt.md | Sonnet (Opus for complex UX) | Playwright screenshots, 25-item QA, AI visual judgment |

### Agent Dispatch Templates

**Writer:**
```
Agent tool (general-purpose, isolation: worktree):
  description: "Write change-set N: [brief name]"
  prompt: [load writer-prompt.md, fill template variables]
```

**Guardian:**
```
Agent tool (general-purpose):
  description: "Guardian: verify structural safety of change-set N"
  model: opus
  prompt: [load guardian-prompt.md, paste Writer's report]
```

**Overseer:**
```
Agent tool (architect):
  description: "Overseer: verify requirement alignment for change-set N"
  model: opus
  prompt: [load overseer-prompt.md, paste Writer + Guardian reports]
```

**PM-Admin:**
```
Agent tool (general-purpose):
  description: "PM-Admin: requirements quality review for change-set N"
  model: opus
  prompt: [load pm-admin-prompt.md, paste all preceding reports]
```

**Designer:**
```
Agent tool (general-purpose):
  description: "Designer: UI/UX quality review for change-set N"
  prompt: [load designer-prompt.md, provide target URLs]
```

---

## Gate Rules

### Evidence-of-Execution Rule (all gates)

No gate may output APPROVED/YES without ALL of:
1. Code execution evidence (Bash output or test results)
2. File existence evidence (Read/Grep result with file:line)
3. Evidence from the SAME session (not stale)

**Prohibited phrases as evidence:**
- "exists" / "wrote" / "should pass" / "documented"
- These are claims, not evidence.

**Required evidence format:**
- "Executed `npm test` → output: 12 passed, 0 failed"
- "Grep found `functionName` at src/utils.ts:42"

### Circuit Breaker (Guardian)

- Round 1 rejection: Provide specific, actionable fixes
- Round 2 same issues: Provide exact code patches
- Round 3: HARD STOP → GUARDIAN_ESCALATE → human decides

### bochi Integration (PM-Admin)

```bash
# Check availability
ls ~/.claude/bochi-data/index.jsonl 2>/dev/null && echo "AVAILABLE" || echo "UNAVAILABLE"

# Search judgment patterns
grep -i "keyword" ~/.claude/bochi-data/index.jsonl | \
  python3 -c "import sys,json; lines=sys.stdin.readlines(); entries=[json.loads(l) for l in lines]; entries.sort(key=lambda x: x.get('date',''), reverse=True); [print(json.dumps(e)) for e in entries[:30]]"
```

PM-Admin output MUST show:
```
bochi 記憶状態:
- index.jsonl: LOADED (N entries) | PARTIAL | UNAVAILABLE
- user-profile.yaml pm_admin: LOADED | UNAVAILABLE
- Referenced records: [title (date), ...]
```

If UNAVAILABLE → safe defaults, all decisions require user confirmation.

---

## Anti-Patterns (embedded in all 5 agent prompts)

| # | Pattern | Detection | Action |
|---|---------|-----------|--------|
| 1 | Spec-as-Done Illusion | Spec treated as "implemented" | Require execution evidence |
| 2 | Phantom Addition Fallacy | "Add" planned for existing thing | Read file first, prove absence |
| 3 | Delegated Verification Deficit | Trusting subagent reports | Independent verification (VP-1) |
| 4 | Delta Thinking Trap | "+N points" estimation | Full rubric re-evaluation |
| 5 | Stale Context Divergence | Old line numbers used | Re-read files, use content anchors |
| 6 | Spec-without-Implementation-Table | Spec refs external components | Append ✅/❌ status table |
| 7 | Precondition-as-Assumption | Hidden test preconditions | Extract as independent tests |
| 8 | High-Risk-Implementation-Gap | Session-external work | ⚠️ WARNING + user confirm |
| 9 | Disconnected-Bloodline | External connection unverified | Reachability test required |
| 10 | Deployment-Sync Blindness | git repo path ≠ runtime path | `diff <git> <runtime>` verification |
| 11 | Spec-Layer Blindness (修正した気になる) | Type B change with structural-only review | Type B Gates: Reproduce → Delta → E2E |
| 12 | Agent-Skip Rationalization (勝手にフロー縮小) | Checkpoint Template unfilled or deviated | Fill Checkpoint, user confirms before dispatch |

---

## Quality Standards

Quality evaluation uses `quality-standards.md` (symlink → `bochi-data/master-quality-review.md`), which defines the 8-axis rubric:

1. Design & Architecture
2. Functionality & Correctness
3. Complexity & Readability
4. Testing & Reliability
5. Security
6. Documentation & Usability
7. Performance & Efficiency
8. Automation & Self-Improvement

**Ship-ready threshold:** 70/80 (87.5%)
**CRITICAL: 0 | HIGH: 0** required for approval.

---

## Research Sources

| # | Source | Applied To |
|---|--------|-----------|
| 1 | Anthropic Multi-Agent Research | Model selection, parallelization |
| 2 | Addy Osmani (Google Chrome) | 3-5 agent optimal, worktree isolation |
| 3 | Microsoft Azure AI Orchestration | Sequential + Maker-Checker pattern |
| 4 | Amazon 90-day Code Reset (2026-03) | Guardian Tier-1 thinking |
| 5 | Glen Rhodes Blast Radius | Review load increase, VP-1 |
| 6 | Propel Code Guardrails | 3-tier risk routing |
| 7 | CodeRabbit 2025 | AI code 2.74x vulnerabilities |
| 8 | Baymard Institute UX | 207 heuristics → 25 items |
| 9 | Deloitte Decision AI | Quality checkpoints, audit trail |
| 10 | Prompt Engineering 2026 | XML tags +23%, thinking -40% hallucination |
| 11 | DORA 2025 Report | AI review +42-48% bug detection |
| 12 | Kinde Spec Drift | Behavioral drift ≠ data drift |

---

## Token Usage Estimates

| Tier | Agents | Input Tokens | Output Tokens | Est. Cost | Est. Time |
|------|--------|-------------|--------------|-----------|-----------|
| Standard | Writer + Guardian + Overseer-std + PM-Admin-std | 20K-35K | 10K-18K | ~$1-3 | ~8-12 min |
| Full | + Designer | 30K-50K | 15K-25K | ~$3-8 | ~15-25 min |

---

## Troubleshooting

**GUARDIAN_ESCALATE (Round 3 deadlock):**
The Guardian has rejected 3 times. Human must decide:
1. **Communication gap** → Rewrite the requirement more precisely, re-dispatch Writer
2. **Architectural issue** → The change is too large for the current architecture; split it
3. **Scope too large** → Break into smaller change-sets and run forge_ace on each

**Designer cannot capture screenshots:**
- Playwright not installed → Designer uses Manual Screenshot Fallback (Phase 0c)
- User provides screenshots at `/tmp/forge_ace_screen_*.png`
- Designer proceeds with QA checklist on manually provided images

---

## File Structure

```
~/.claude/skills/forge_ace/
├── SKILL.md                  ← This file (orchestration)
├── anti-patterns.md          ← 12 patterns reference card (DRY across all agents)
├── quality-standards.md      ← symlink → ../../bochi-data/master-quality-review.md
├── writer-prompt.md          ← v3.0 (XML, Red Team, Evidence-of-Execution)
├── guardian-prompt.md         ← v3.0 (Risk-tier, Blast Radius Score, 8-axis)
├── overseer-prompt.md         ← v3.0 (Behavioral Drift, DESIGN.md L1.5, Regression Guards)
├── pm-admin-prompt.md         ← v1.0 (Scope Delegation, bochi, Two-Tier Memory, 4-axis)
├── designer-prompt.md         ← v1.0 (Playwright, 25-item QA, AI Visual Judgment)
├── checklists/
│   ├── ai-defect-scan.md     ← Guardian Phase 2.5 (extracted)
│   └── connectivity-check.md ← Guardian Phase 2.7 (extracted)
└── test-scenarios/
    ├── scenario-s-small-change.md    ← Standard-tier fixture (Writer + Guardian + Overseer-std + PM-Admin-std)
    ├── scenario-m-api-change.md      ← Standard-tier fixture (API change)
    └── scenario-l-fullstack-with-ui.md ← Full-tier fixture (all 5 agents)
```
