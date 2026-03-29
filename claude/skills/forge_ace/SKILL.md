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

Use forge_ace (instead of triple-agent-coding) when:
- Changes span requirements → design → implementation
- UI/UX changes need design quality verification
- PM-level scope delegation is needed ("全部任せる" / "ここまで作って" / "設計だけ見て")
- The task involves bochi-data pattern matching for judgment

Use triple-agent-coding when:
- Code-only changes without UI or requirements review needed

---

## Session Types

### Coding Session (code changes)

Triggered when: code creation or modification is needed.

**Complexity Classifier** determines agent roster:

```
S (Small):  diff ≤3 files, ≤100 lines, no API surface change, no UI
  → Writer + Guardian (8-axis FULL — quality is size-independent)

M (Medium): diff 4-10 files OR >100 lines OR API surface change
  → Writer + Guardian + Overseer

L (Large):  diff >10 files OR cross-module OR UI changes OR auth/payment
  → Writer + Guardian + Overseer + PM-Admin ∥ Designer
```

**HARD-GATE: Quality is size-independent.**
Even S-size gets Guardian's quality-standards.md 8-axis evaluation.
Size controls agent COUNT, not quality STANDARDS.

**Flow:**
```
S: Writer → Guardian(8-axis) → DONE
M: Writer → Guardian → Overseer → DONE
L: Writer → Guardian → Overseer → PM-Admin ∥ Designer → PM-Admin final → DONE
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
Code change AND UI change → Coding Session (L-size, Designer participates in parallel)
Code change only         → Coding Session (S/M/L by classifier)
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

---

## Quality Standards

Quality evaluation uses `quality-standards.md` (symlink → `bochi/references/master-quality-review.md`), which defines the 8-axis rubric:

1. Design & Architecture
2. Functionality & Correctness
3. Complexity & Readability
4. Testing & Reliability
5. Security
6. Documentation & Usability
7. Performance & Efficiency
8. Community & OSS Maturity

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

| Size | Agents | Input Tokens | Output Tokens | Est. Cost | Est. Time |
|------|--------|-------------|--------------|-----------|-----------|
| S | Writer(Sonnet) + Guardian(Opus) | 5K-15K | 3K-8K | ~$0.3-1.0 | ~3-5 min |
| M | + Overseer(Opus) | 15K-30K | 8K-15K | ~$1-3 | ~8-12 min |
| L | + PM-Admin(Opus) + Designer(Sonnet) | 30K-50K | 15K-25K | ~$3-8 | ~15-25 min |

Use S for most changes. Upgrade to M/L only when the Complexity Classifier requires it.
L-size with all 5 agents is expensive — confirm the change justifies the cost.

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

**bochi-data UNAVAILABLE:**
- PM-Admin operates in degraded mode: all decisions require explicit user confirmation
- Quality assessment falls back to code-direct analysis (no judgment pattern matching)
- All decisions marked: "bochi-data UNAVAILABLE — code-direct analysis"

---

## File Structure

```
~/.claude/skills/forge_ace/
├── SKILL.md                  ← This file (orchestration)
├── anti-patterns.md          ← 9 patterns reference card (DRY across all agents)
├── quality-standards.md      ← symlink → ../bochi/references/master-quality-review.md
├── writer-prompt.md          ← v3.0 (XML, Red Team, Evidence-of-Execution)
├── guardian-prompt.md         ← v3.0 (Risk-tier, Blast Radius Score, 8-axis)
├── overseer-prompt.md         ← v3.0 (Behavioral Drift, DESIGN.md L1.5, Regression Guards)
├── pm-admin-prompt.md         ← v1.0 (Scope Delegation, bochi, Two-Tier Memory, 4-axis)
├── designer-prompt.md         ← v1.0 (Playwright, 25-item QA, AI Visual Judgment)
├── checklists/
│   ├── ai-defect-scan.md     ← Guardian Phase 2.5 (extracted)
│   └── connectivity-check.md ← Guardian Phase 2.7 (extracted)
└── test-scenarios/
    ├── scenario-s-small-change.md    ← S-size fixture (Writer + Guardian)
    ├─��� scenario-m-api-change.md      ← M-size fixture (+ Overseer)
    └── scenario-l-fullstack-with-ui.md ← L-size fixture (all 5 agents)
```
