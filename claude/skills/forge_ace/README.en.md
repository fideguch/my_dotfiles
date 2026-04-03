# forge_ace v4.0

**5-Agent Quality Gate for Code and Text**

A multi-layered quality gate system where five specialized agents verify changes across code, specifications, prompts, and configuration files.

---

## Mission

> Bridge the gap between "the code works" and "the right thing was built."

Passing tests and compiling code do not guarantee quality. Alignment with requirements, consistency across specification documents, visual fidelity of UI, and coherence with product vision all require systematic verification. forge_ace was designed to close these gaps.

### Why This Exists

| Problem | Traditional Approach | forge_ace Approach |
|---------|---------------------|-------------------|
| AI-generated code has 2.74x more vulnerabilities (CodeRabbit 2025) | Manual code review | Guardian: automated risk analysis + 8-axis quality evaluation |
| Writing a spec is mistaken for completing the implementation | Checklists | Type B gates: behavioral evidence required |
| UI implementation drifts from design intent | Design review meetings | Designer: automated screenshots + 25-item QA |
| Requirements-to-implementation drift goes undetected | PM manual review | Overseer: requirement decomposition + drift detection |

---

## Architecture

```
                          User Requirement
                              |
                    [Step 1] Session Init
                    Classify: Tier (Standard/Full)
                             Type (A: Code / B: Text)
                              |
                    [Step 2] Dispatch Checkpoint
                    User Confirmation (HARD-GATE)
                              |
                    [Step 3] Plan Quality Gate
                    GAFA-standard plan validation
                              |
                    [Step 4] Writer ----------+
                    TDD + Red Team            |
                    Type B: Reproduce->Delta  |
                              |               |
                    [Step 5] Guardian         |
                    Blast Radius + 8-Axis     |
                    Type B: Integrity Check   |
                              |               |
                    [Step 6] Overseer         |
                    Req Alignment + Drift     |
                              |               |
                    [Step 7] PM-Admin         |  [Step 8] Designer
                    Scope + bochi Memory      |  Screenshots
                              |               |  25-Item QA
                              +-------+-------+
                                      |
                            [Step 9] Complete
                            Type B: E2E Execution Mandate
```

### Session Types

| Type | Agent Composition | Use Case |
|------|------------------|----------|
| **Standard** | Writer -> Guardian -> Overseer(std) -> PM-Admin(std) | Code-only, no UI |
| **Full** | Writer -> Guardian -> Overseer(full) -> PM-Admin(full) + Designer | UI/UX changes present |
| **Design Session** | PM-Admin -> Designer -> mutual review | UI/UX only |

---

## Core Concepts

### Type A and Type B

The defining feature of forge_ace is classifying change targets into two types, each with its own optimal verification strategy.

| | Type A (Code) | Type B (Text) |
|---|--------------|---------------|
| **Targets** | `.ts`, `.py`, `.go`, `.rs`, etc. | `.md`, `.yaml`, `.json`, SKILL.md, prompts |
| **Verification** | Test execution, type checking, Bash evidence | Reproduce -> Delta -> E2E behavioral evidence |
| **Writer** | RED-GREEN TDD | Reproduce-Before-Fix + Delta Demonstration |
| **Guardian** | Blast radius + 8-axis evaluation | Structural review + "cannot verify behavior" flag |
| **Final Gate** | All tests pass | E2E Execution Mandate |

### Evidence-of-Execution

An ironclad rule applied to every agent:

- **Bash execution output** is the only valid evidence
- "Tests should pass" or "looks correct" are not evidence
- Guardian does not trust Writer's report -- it re-runs tests independently
- For Type B, file content changes are not evidence; **behavioral change** is evidence

### 12 Anti-Patterns

Structural failure patterns extracted from real incidents. All agents detect and prevent these:

| # | Pattern | Summary |
|---|---------|---------|
| 1 | Spec-as-Done Illusion | Treating a spec as completed implementation |
| 2 | Phantom Addition Fallacy | Planning to "add" something that already exists |
| 3 | Delegated Verification Deficit | Trusting another agent's report without checking |
| 4 | Delta Thinking Trap | Estimating quality as "+N points" instead of full re-evaluation |
| 5 | Stale Context Divergence | Referencing outdated line numbers or stale state |
| 6 | Spec-without-Implementation-Table | Missing implementation status for external dependencies |
| 7 | Precondition-as-Assumption | Hidden test preconditions that are not independently verified |
| 8 | High-Risk-Implementation-Gap | Session-external work referenced without confirmation |
| 9 | Disconnected-Bloodline | Unreachable external connections referenced in code |
| 10 | Deployment-Sync Blindness | Git path diverges from runtime path |
| 11 | Spec-Layer Blindness | Treating text edits as completed fixes without behavioral verification |
| 12 | Agent-Skip Rationalization | Agents unilaterally shrinking the pipeline |

---

## The Five Agents

### Writer

**Role**: Implement the change  
**Model**: Sonnet (Opus for multi-file changes)  
**Key Phases**:
1. **Comprehension** -- Full read of target files, high-risk scan
2. **Test First (RED)** -- Write failing tests before implementation
3. **Implementation (GREEN)** -- Minimal code to pass all tests
4. **30% Check** -- Edge cases, security, integration, concurrency
5. **Red Team Self-Attack** -- Input fuzzing, state corruption, dependency failure, privilege escalation
6. **Self-Review** -- Requirement mapping, scope deviation check

### Guardian

**Role**: Verify structural safety  
**Model**: Opus  
**Key Phases**:
1. **VP-1 Independent Verification** -- Distrust Writer's report; verify independently
2. **Risk-Tier Routing** -- LOW / MEDIUM / HIGH
3. **Blast Radius Analysis** -- Importer tracing, type contracts, config, side effects
4. **AI Code Defect Scan** -- Phantom dependencies, preconditions, API freshness, over-engineering, OWASP
5. **Connectivity + Deployment-Sync** -- Cross-server reachability, git path = runtime path
6. **8-Axis Quality Evaluation** -- Design, Functionality, Complexity, Testing, Security, Docs, Performance, Automation

### Overseer

**Role**: Verify requirements alignment  
**Model**: Opus  
**Key Phases**:
1. **Requirement Decomposition** -- Break into testable claims
2. **Implementation Verification (HARD-GATE)** -- Read actual code, verify each requirement
3. **Type B Behavioral Verification** -- Assess reproduction evidence + delta convincingness + define E2E scenario
4. **Drift Detection** -- Scope creep, under-delivery, misinterpretation, vision alignment, behavioral drift
5. **Institutional Knowledge** [Full] -- Cross-reference coding conventions and past failures
6. **DESIGN.md Verification** [Full] -- Tokens, hierarchy, HEAL protocol

### PM-Admin

**Role**: Product quality gate  
**Model**: Opus  
**Key Phases**:
1. **bochi Memory Load** -- Judgment patterns, user profile, success-rate calibration
2. **Scope Compliance (HARD-GATE)** -- Enforce scope boundaries per delegation level
3. **Runtime Verification (HARD-GATE)** -- Run tests independently, Type B chain completeness
4. **E2E Execution Mandate** [Type B] -- Mandate E2E scenario execution after all-agent approval

### Designer

**Role**: UI/UX quality review (Full tier only)  
**Model**: Sonnet (Opus for complex UX)  
**Key Phases**:
1. **Screenshot Capture** -- 3 viewports via Playwright (desktop/mobile/tablet)
2. **25-Item QA Checklist** -- Layout, typography, navigation, visual design, accessibility, performance
3. **AI Visual Judgment** -- Compare against DESIGN.md, detect discrepancies
4. **DESIGN.md Compliance** -- Tokens, component hierarchy, HEAL protocol

---

## Quality Standards

### 8-Axis Evaluation

| # | Axis | Standard |
|---|------|----------|
| 1 | Design & Architecture | ISO 25010: Maintainability |
| 2 | Functionality & Correctness | ISO 25010: Functional Suitability |
| 3 | Complexity & Readability | Google eng-practices |
| 4 | Testing & Reliability | ISO 25010 + CISQ |
| 5 | Security | ISO 25010 + CISQ |
| 6 | Documentation & Usability | ISO 25010: Usability |
| 7 | Performance & Efficiency | ISO 25010: Performance Efficiency |
| 8 | Automation & Self-Improvement | forge_ace + DORA 2025 |

### Ship-Ready Criteria

- **Passing score**: 70/80 (87.5%)
- **Mandatory**: CRITICAL: 0 | HIGH: 0

---

## State Machine

Session state is managed in `/tmp/.forge-ace-session.json`:

```
INIT -> CLASSIFIED -> CHECKPOINT_FILLED -> USER_CONFIRMED
  -> WRITER_DISPATCHED -> WRITER_DONE
  -> GUARDIAN_DISPATCHED -> GUARDIAN_DONE
  -> OVERSEER_DISPATCHED -> OVERSEER_DONE
  -> PM_ADMIN_DISPATCHED -> PM_ADMIN_DONE
  -> [DESIGNER_DISPATCHED -> DESIGNER_DONE]  (Full only)
  -> COMPLETE
```

Each transition is recorded with a timestamp. A dispatch hook prevents invalid state transitions.

---

## Cost Estimates

| Tier | Agents | Input Tokens | Output Tokens | Est. Cost | Est. Time |
|------|--------|-------------|--------------|-----------|-----------|
| Standard | 4 | 20K-35K | 10K-18K | ~$1-3 | ~8-12 min |
| Full | 5 | 30K-50K | 15K-25K | ~$3-8 | ~15-25 min |

---

## File Structure

```
~/.claude/skills/forge_ace/
|
|-- README.md                     <- Japanese documentation
|-- README.en.md                  <- This file (English)
|-- SKILL.md                      <- Orchestration protocol
|
|-- writer-prompt.md              <- Writer agent prompt
|-- guardian-prompt.md            <- Guardian agent prompt
|-- overseer-prompt.md            <- Overseer agent prompt
|-- pm-admin-prompt.md            <- PM-Admin agent prompt
|-- designer-prompt.md            <- Designer agent prompt
|
|-- anti-patterns.md              <- 12-pattern reference card
|-- plan-quality-rubric.md        <- GAFA plan quality rubric
|-- quality-standards.md          -> bochi-data/master-quality-review.md
|
|-- references/
|   |-- origin-and-sources.md     <- Mission, research sources, token estimates
|   |-- evidence-rules.md         <- Evidence-of-Execution shared rules
|   |-- type-b-gates.md           <- Type B change verification gates
|   `-- type-b-pqg.md            <- Type B Plan Quality Gate checklist
|
|-- checklists/
|   |-- ai-defect-scan.md         <- Guardian Phase 2.5
|   |-- connectivity-check.md     <- Guardian Phase 2.7
|   `-- cross-document-integrity.md <- Guardian Phase 2 Type B
|
|-- tests/
|   |-- test-dispatch-guard.sh    <- Dispatch guard hook tests (14 cases)
|   `-- test-state-machine.sh     <- State machine tests (12 cases)
|
`-- test-scenarios/
    |-- scenario-s-small-change.md        <- S: Doc fix (Standard)
    |-- scenario-m-api-change.md          <- M: API endpoint addition (Standard)
    |-- scenario-m-type-b-spec-fix.md     <- M: Spec fix (Type B)
    `-- scenario-l-fullstack-with-ui.md   <- L: Fullstack + UI (Full)
```

---

## Research Foundation

| # | Source | Applied To |
|---|--------|-----------|
| 1 | Anthropic Multi-Agent Research | Model selection, parallelization |
| 2 | Addy Osmani (Google Chrome) | 3-5 agent optimal, worktree isolation |
| 3 | Microsoft Azure AI Orchestration | Sequential + Maker-Checker pattern |
| 4 | Amazon 90-day Code Reset (2026-03) | Guardian Tier-1 thinking |
| 5 | Glen Rhodes Blast Radius | Review load increase, VP-1 |
| 6 | Propel Code Guardrails | 3-tier risk routing |
| 7 | CodeRabbit 2025 | AI code 2.74x vulnerabilities |
| 8 | Baymard Institute UX | 207 heuristics -> 25 items |
| 9 | Deloitte Decision AI | Quality checkpoints, audit trail |
| 10 | Prompt Engineering 2026 | XML tags +23%, thinking -40% hallucination |
| 11 | DORA 2025 Report | AI review +42-48% bug detection |
| 12 | Kinde Spec Drift | Behavioral drift != data drift |

---

## Troubleshooting

| Situation | Resolution |
|-----------|-----------|
| GUARDIAN_ESCALATE (Round 3) | Clarify requirements, split the change, or decide manually |
| Designer cannot capture screenshots | Playwright not installed -> Manual Screenshot Fallback |
| Type B: all agents approved but E2E fails | By design: E2E Mandate reverts to REJECTED |
| Writer returns NEEDS_CONTEXT | Review scope definition, add missing files |
| State machine invalid transition | Check `/tmp/.forge-ace-session.json`, inspect dispatch hook logs |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v4.0 | 2026-04-01 | Hook enforcement + state machine + prompt compression (-43%) |
| v3.1 | 2026-03-30 | Type A/B classification + E2E gates |
| v2.0 | 2026-03-29 | Plan Quality Gate + bochi integration |
| v1.2 | 2026-03-28 | 5-agent pipeline established |

---

## License

Private skill -- personal use.
