# GAFA Plan Quality Gate Rubric

> Plan-level quality gate synthesized from GAFA engineering practices.
> Google Design Doc + Amazon PRFAQ + Apple Demo-Driven + Meta Incremental + NVIDIA Safety + DORA 2025.
> bochi-data integration: PDCA 3-cycle validation, VP-6 estimation protocol, scenario test mandate.
> Referenced by planner agent v2.0 and forge_ace SKILL.md Plan Quality Gate section.

## Gate Routing

| Gate | Name | Standard | Full |
|------|------|----------|------|
| 0 | Problem Clarity | Required | Required |
| 1 | Solution Design | Required | Required |
| 2 | Feasibility Proof | Skip | Required |
| 3 | Implementation Readiness | Skip | Required |
| 4 | Risk Assessment | Required | Required |
| 5 | Review Quality | Required | Required |

---

## Gate 0: Problem Clarity (Amazon PRFAQ)

| Criteria | Evidence Required |
|----------|------------------|
| Problem statement is specific and falsifiable | User quote or data point |
| Target user/system identified | Named persona or component |
| Success criteria are measurable (not vague) | Metric + threshold (bochi: "PASSの定量定義必須") |
| Non-goals explicitly listed (≥1) | Written non-goal statement |

**Pass**: All 4 met. **Fail**: Problem vague or unmeasurable success criteria.

## Gate 1: Solution Design (Google Design Doc + Apple Demo)

| Criteria | Evidence Required |
|----------|------------------|
| Architecture described with component boundaries | Diagram or structured list |
| Data flow documented (input → transform → output) | Flow description |
| Alternatives considered (≥2) with trade-off reasoning | Comparison table |
| Demo scenario defined ("done" = user-visible outcome) | Outcome description |

**Pass**: All 4 met. **Fail**: No alternatives (RF-1) OR no demo scenario.

## Gate 2: Feasibility Proof (Apple Demo-Driven + Amazon)

| Criteria | Evidence Required |
|----------|------------------|
| Technical spike OR existing code proves approach | Execution output or code file:line |
| Dependencies verified to exist and be accessible | `ls`/`which`/`npm ls` output |
| Performance characteristics estimated | Benchmark or basis-backed estimate |

**HARD-GATE (bochi: "実機検証→計画の順序"):**
Plans based on assumptions ("should work") without execution evidence → FAIL.
"Tried it and it works" (Apple) is the gold standard.

**Pass**: Spike exists with execution evidence. **Fail**: Claims without evidence.

## Gate 3: Implementation Readiness (Meta Incremental + DORA)

| Criteria | Evidence Required |
|----------|------------------|
| Steps are ≤1 day each, ≤3 steps per session (bochi VP-6 Rule 3) | Step list with estimates |
| Each step is independently testable (bochi: "シナリオテスト必須") | Test strategy per step |
| Dependencies between steps are explicit | Dependency notation |
| Rollback plan exists for each phase | Rollback description |

**Pass**: Steps decomposed and testable. **Fail**: Monolithic phases or no rollback.

## Gate 4: Risk Assessment (Amazon + NVIDIA Safety)

| Criteria | Evidence Required |
|----------|------------------|
| ≥3 risks identified with likelihood × impact | Risk table |
| Each risk has a mitigation strategy | Mitigation description |
| Session-external risks flagged (Anti-Pattern #8) | High-Risk-Implementation-Gap check |
| Estimation uses VP-6 dual estimate (optimistic/pessimistic) | Two-row estimate table |

**Pass**: Risks documented with mitigations + dual estimates. **Fail**: No risk analysis.

## Gate 5: Review Quality (forge_ace Anti-Patterns + PDCA 3-Cycle)

| Criteria | Evidence Required |
|----------|------------------|
| Anti-patterns #1-12 checked against plan | Checklist with CLEAR/DETECTED |
| If plan targets Type B files, Reproduce-Before-Fix strategy included | Reproduction strategy documented |
| PDCA 3-cycle review completed (bochi method) | Cycle 1: technical, Cycle 2: meta, Cycle 3: coverage |
| Research completion criteria met for size | Research Summary with source counts |
| bochi-data consulted (if available) | bochi memory status line |

**Pass**: All checklists completed. **Fail**: Anti-pattern detected and unresolved.

---

## Red Flags (Immediate FAIL — any gate)

| # | Red Flag | Source |
|---|----------|--------|
| RF-1 | No alternatives considered / trade-off analysis | Google Design Doc |
| RF-2 | Unsolved technical barrier with no spike plan | Amazon PRFAQ / Apple Demo |
| RF-3 | Unclear user/system or unmeasurable success criteria | Amazon PRFAQ |
| RF-4 | "Implementation manual" without WHY reasoning | Google eng-practices |
| RF-5 | No testing strategy | Google eng-practices |
| RF-6 | Security/privacy not addressed | Google / NVIDIA Safety |
| RF-7 | Monolithic change with no incremental path | Meta / DORA 2025 |
| RF-8 | Spec-as-Done: plan describes docs to WRITE, not behavior to BUILD | bochi lesson |
| RF-9 | Type B change planned without behavioral verification strategy | bochi v2.6 lesson |
| RF-10 | Checkpoint Template shows deviation without user approval | Agent-Skip Rationalization |

## Pass/Fail Protocol

- Each gate: **Pass** / **Conditional** / **Fail**
- Any **Fail** → revise plan, re-evaluate failed gate (max 2 iterations)
- **Conditional** → document condition, proceed with user awareness
- All **Pass** → plan approved, proceed to implementation
- After 2 failed iterations → HARD STOP, human decides

## PDCA 3-Cycle Validation (bochi method — Gate 5 detail)

| Cycle | Focus | What to Discover |
|-------|-------|-----------------|
| 1 | Technical validity | Tool availability, type safety, OS deps, error paths |
| 2 | Meta-critique | Prevention vs detection? Symptomatic vs root cause? |
| 3 | Coverage audit | All CRITICAL/HIGH have actions? Verification criteria exist? |

Each cycle MUST modify the plan. "No issues found" on all 3 cycles = insufficient review.
