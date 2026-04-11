---
name: gatekeeper
description: forge_ace併用の実装品質ゲート。仕様徹底確認・実機検証・推測修正禁止・仮説固執防止を強制。RIPER-5/verification-before-completion/trailofbits等の世界的ベストプラクティスに基づく
triggers:
  - "gatekeeper"
  - "ゲートキーパー"
  - "実機検証"
---

# gatekeeper v1.2 — Verify It Works, Not Just Compiles

forge_ace が「コード品質」を��証し��gatekeeper が「実際に動くか・仕様通りか」を保証する。

## Design Sources

| Source | Stars/Scale | Adopted Element |
|--------|------------|-----------------|
| verification-before-completion (openclaw) | Widely adopted | Iron Law + Gate Function |
| RIPER-5 (NeekChaw) | 2,590+ | Mode transition + Forbidden lists |
| context-engineering-kit (NeoLab) | 788+ | Reflexion + quantitative confidence |
| devin.cursorrules (grapeot) | 5,962+ | Screenshot Verification + Self-Evolution |
| trailofbits/skills fp-check | 4,466+ | Rationalizations to Reject |
| CodeScene agentic patterns | Enterprise | Verification layer > code generation |
| Stripe/Airbnb harness | GAFA | Escalation thresholds |
| Google eng-practices | GAFA | Code review checklist |
| ACM/IEEE cognitive bias research | Academic | Fixation Bias structural prevention |
| BrowserStack/TestDino | Industry | Playwright WebKit != real Safari |

## When to Use

- **With forge_ace Full**: All screen implementations (Phase 4+)
- **Standalone**: Bug fixes, debugging, any code claiming "done"
- **Auto-trigger**: Whenever an agent is about to declare work complete

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

---

## Integration with forge_ace

```
[gatekeeper Step 1: RESEARCH (HG-1)]       <-- Before forge_ace Writer
  |
[gatekeeper Step 1.5: UX PROTOCOL (HG-1.5)] <-- UX thinking before code
  |
[forge_ace Writer]                          <-- Implementation
  |  Step 3 (FACTS) — active if external API call or error encountered
  |  Step 4 (HYPOTHESIS) — requires Step 3 (facts) first
  |
[gatekeeper Step 2: CONSISTENCY]            <-- Pre-check before Guardian
  |
[forge_ace Guardian -> Overseer -> PM]      <-- Code quality
  |
[gatekeeper Step 5: VERIFY]                 <-- Post-SHIP
```

Step 1.5 is a **mandatory gate** — runs in both paired and standalone modes.

Step 3 + Step 4 are **inline gates** — they activate during implementation whenever:
- Step 3: Any external API integration or unexpected error requires fact collection first
- Step 4: Any fix attempt fails twice on the same hypothesis. **HG-3 (facts) is a prerequisite for HG-4 (hypothesis)** — facts must be collected before forming hypotheses.
- Shared skip condition: Pure UI-only implementation with zero external API calls and no debugging skips BOTH HG-3 and HG-4

---

## Step 0: Activation

<step id="activate">

1. **Resolve project directory**:
   - Read `GATEKEEPER_SESSION_DIR` environment variable
   - If NOT set: **BLOCK** — ask the user to specify the project root directory
     ```
     [gatekeeper] GATEKEEPER_SESSION_DIR is not set.
     Please set it to your project root: export GATEKEEPER_SESSION_DIR=/path/to/project
     ```
   - Fallback: `process.cwd()` (hooks only — SKILL.md requires the env var)

2. Determine mode:
   - **Paired**: forge_ace Full is running → gatekeeper wraps around it
   - **Standalone**: Bug fix or debugging without forge_ace

3. Write `{GATEKEEPER_SESSION_DIR}/.gatekeeper/session.json`:
   ```json
   {
     "version": "1.2",
     "created": "[ISO]",
     "project_dir": "[GATEKEEPER_SESSION_DIR value]",
     "mode": "paired|standalone",
     "gates": {
       "hg1": {"status": "pending", "evidence": null},
       "hg1_5": {"status": "pending", "evidence": null},
       "hg2": {"status": "pending", "evidence": null},
       "hg3": {"status": "pending|skipped", "evidence": null},
       "hg4": {"status": "pending|skipped", "attempts": []},
       "hg5": {"status": "pending", "verdict": null}
     },
     "hypothesis_tracker": {
       "current": null,
       "failed": [],
       "attempt_count": 0
     },
     "final_status": null
   }
   ```

4. **Auto-migrate**: If `/tmp/.gatekeeper-session.json` exists, copy it to the new location and delete the old file.

5. Update session: `state -> ACTIVATED`

**Directory structure**:
```
{project_root}/.gatekeeper/
├── session.json          <- Active session
└── history/              <- Completed sessions (max 3, rotated by Stop hook)
    ├── 2026-04-11T12-00-00Z.json
    └── ...
```

</step>

---

## Step 1: RESEARCH BEFORE CODE (HG-1)

<HARD-GATE id="HG-1">
NO CODE before reading specs and Figma. Violation = implementation restart.
</HARD-GATE>

Based on: RIPER-5 RESEARCH mode (code forbidden during research phase)

<step id="hg1-research">

Before writing ANY implementation code:

1. **Read designs/**: All related markdown files for the target feature
   ```bash
   grep -rl "target_feature_keyword" designs/
   ```
2. **Figma get_design_context**: Fetch screenshot + text info for the target screen
3. **Grep existing patterns**: Find Phase 3 screens with equivalent patterns
   ```bash
   grep -rl "ComponentName" src/app/ src/components/
   ```
4. **Ask if unclear**: One question at a time. Wait for answer before proceeding.
   - Do NOT batch questions. 1 question = 1 answer = then next question.
   - Reference: `checklists/pre-implementation.md` for full checklist

Update session: `gates.hg1.status -> PASS, gates.hg1.evidence -> [list of files read]`

**Forbidden**:
- Starting code before reading ALL relevant design docs
- Implementing without Figma screenshot verification
- Guessing component specs instead of reading designs/component-definitions.md
- Assuming layout without checking Phase 3 precedent
- Asking the user a question that can be answered by reading designs/ (grep first, ask second)

</step>

---

## Step 1.5: UX THINKING PROTOCOL (HG-1.5)

<HARD-GATE id="HG-1.5">
NO CODE before writing down UX thinking. Violation = implementation restart.
</HARD-GATE>

Based on: UX Thinking Protocol extracted from HG-1 into independent gate for enforcement in ALL modes.

<step id="hg1_5-ux-protocol">

Mandatory in both paired and standalone modes. Write down before implementing:

```
SCREEN: [screen name]
USER GOAL: What does the user want to accomplish here?
FIRST ACTION: What will the user tap/click first?
HAPPY PATH: [step 1] -> [step 2] -> [step 3] -> [success state]
ERROR PATH: What can go wrong? How does the user recover?
EDGE CASES: Empty state, slow network, expired session
```

For standalone bug fixes, adapt the protocol:
```
SCREEN: [affected screen]
USER GOAL: What was the user trying to do when the bug occurred?
FIRST ACTION: What triggers the bug?
HAPPY PATH: [expected behavior after fix]
ERROR PATH: What if the fix introduces a regression?
EDGE CASES: Other screens/flows affected by the same code path
```

Update session: `gates.hg1_5.status -> PASS, gates.hg1_5.evidence -> [UX protocol written]`

**Forbidden**:
- Skipping UX protocol in any mode (paired or standalone)
- Writing code before completing all 6 protocol fields
- Copying a generic template without filling in specific details

</step>

---

## Step 2: CONSISTENCY GATE (HG-2)

<HARD-GATE id="HG-2">
NO deviation from Phase 3 quality. Existing components and DS tokens are law.
This is a pre-check before forge_ace Guardian. Guardian checks code quality; HG-2 checks DS compliance and component reuse.
</HARD-GATE>

Based on: Google eng-practices code review standards

<step id="hg2-consistency">

During implementation, verify:

1. **Component reuse**: Before creating ANY new component:
   ```bash
   grep -rl "similar_pattern" src/components/
   ```
   If existing component found -> reuse it, don't create new one.

2. **DS token compliance**:
   - Colors: Only from design-system.md semantic tokens
   - Shadows: SM/MD only, no solid shadow
   - Border radius: Per component spec
   - Touch targets: min-h-[44px] on all interactive elements
   - Typography: Per DS scale only

3. **Phase 3 pattern match**: Every new screen must follow patterns from existing screens
   - Layout structure (GlobalHeader + content + BottomNav/FixedCTABar)
   - Button hierarchy (Primary top + semantic color, Secondary bottom)
   - Error/empty/loading states

4. **Minimal fix first**: When fixing bugs, try the smallest possible change before architectural restructuring
   - 1-line fix > component rewrite
   - If minimal fix doesn't work, THEN consider structural change
   - `git show HEAD:path/to/file` to check what was working before

5. **Research validation**: Before adopting competitive research into implementation:
   - Reference: `checklists/research-validation.md`

Update session: `gates.hg2.status -> PASS`

**Forbidden**:
- Custom CSS when a DS component exists
- New color values not in design-system.md
- Touch targets under 44px
- Breaking existing component APIs
- Architectural restructuring before trying minimal fix (Category 4 pattern)

</step>

---

## Step 3: FACTS BEFORE FIX (HG-3)

<HARD-GATE id="HG-3">
NO fix based on guessing. Collect facts FIRST, then fix. Violation = rollback.
</HARD-GATE>

Based on: CodeScene verification layer + ACM cognitive bias research

<step id="hg3-facts">

Applies: Bug fixing AND new feature API integration (always active).

When a bug is reported or discovered:

1. **Collect facts FIRST** (in this order):
   a. Server logs (`console.log` at each step of the failing path)
   b. Browser console errors (exact error message)
   c. Network tab (request/response, status codes, cookies)
   d. External service dashboard (Stripe, Supabase, etc.)

2. **External API verification**:
   ```bash
   # ALWAYS test API behavior before integrating
   node -e "fetch('...').then(r => r.json()).then(console.log)"
   ```

3. **Report format**:
   - FACT: What actually happened (with evidence)
   - HYPOTHESIS: What might be causing it (clearly labeled as hypothesis)
   - PLAN: How to verify the hypothesis (not how to fix it yet)

Update session: `gates.hg3.status -> PASS, gates.hg3.evidence -> [facts collected]`

**Forbidden**:
- Modifying code based on guessing alone
- Reporting "Playwright PASS" as "verified working"
- Declaring "fixed" without fresh evidence from the actual environment
- Using "should work", "probably fixed", "seems correct"

</step>

---

## Step 4: HYPOTHESIS ABANDONMENT (HG-4)

<HARD-GATE id="HG-4">
2 failures on same hypothesis = ABANDON. 3rd attempt on same direction = BLOCKED.
</HARD-GATE>

Based on: ACM Fixation Bias prevention + Stripe/Airbnb harness escalation thresholds

<step id="hg4-abandon">

**Prerequisite**: HG-3 (FACTS) must be completed before HG-4 can activate. Facts → then hypothesis.
If HG-3 is skipped (shared skip condition), HG-4 is also skipped.

Applies: Debugging (always active).

Debugging protocol:

1. **Attempt 1**: Test hypothesis A
   - If FAIL -> document what happened, adjust approach
   - Update session: `hypothesis_tracker.attempt_count -> 1`

2. **Attempt 2**: Test refined hypothesis A
   - If FAIL -> **MANDATORY STOP**. Hypothesis A is DEAD.
   - Update session: `hypothesis_tracker.failed -> [A], attempt_count -> 2`

3. **Before attempt 3** (REQUIRED):
   a. State: "Hypothesis A has failed twice. Abandoning."
   b. List 3 DIFFERENT cause hypotheses (divergent thinking):
      - Hypothesis B: [completely different angle]
      - Hypothesis C: [completely different angle]
      - Hypothesis D: [completely different angle]
   c. For each, answer: "What evidence would DISPROVE this hypothesis?"
   d. Ask user for input if stuck

4. **Escalation**: If 3 different hypotheses all fail:
   - STOP coding
   - Ask user for real-device facts (screenshots, console logs, behavior description)
   - Web research for the exact error/behavior combination
   - Create a fresh plan with new information

**"Same direction" definition** (operational test for AI):
- Same error message persists after fix -> same direction
- Fix targets the same file/function as previous attempt -> same direction
- Fix is a parameter/value change within the same API call -> same direction
- Fix changes a DIFFERENT subsystem (e.g., server vs client, cookie vs redirect) -> NEW direction

**Forbidden**:
- 3rd attempt in the same direction as attempts 1-2
- "Minor tweak" of a failed approach (same direction = same hypothesis)
- Continuing without listing alternative hypotheses
- Skipping the divergent thinking step

</step>

---

## Step 5: VERIFY ON DEVICE (HG-5)

<HARD-GATE id="HG-5">
NO "done" without device verification. Playwright PASS = code structure test, NOT UX test.
</HARD-GATE>

Based on: BrowserStack/TestDino research + verification-before-completion Iron Law

<step id="hg5-verify">

After forge_ace SHIP (or after any fix):

**Self-Check Protocol** — run all 5 items before claiming done:
→ Full protocol: `references/rationalizations-to-reject.md#self-check-protocol`

Then:

1. **Clean build**:
   ```bash
   rm -rf .next && npm run build && npm start
   ```

2. **Browser verification** (developer does this):
   - Open target page in browser
   - Walk through the user flow
   - Check: layout, interactions, data loading, error states

3. **Report status clearly**:
   - `VERIFIED`: Checked with own eyes in browser (state what was checked)
   - `BUILT`: Code compiles and builds (NOT verified in browser)
   - `TESTED`: Playwright/vitest passes (NOT verified in browser)
   - `NEEDS_USER`: Requires real device check (iOS Safari, mobile, etc.)

4. **User verification request** (for mobile/device-specific):
   - Tell user exactly what to test
   - Tell user exactly what URL to open
   - Ask for screenshot or behavior description

Update session: `gates.hg5.status -> PASS, gates.hg5.verdict -> [VERIFIED|BUILT|TESTED|NEEDS_USER], final_status -> [verdict]`

**Forbidden**:
- Using `VERIFIED` without actually opening a browser
- Reporting Playwright PASS as device verification
- Claiming "done" with only `BUILT` or `TESTED` status
- Skipping `rm -rf .next` before verification build

</step>

---

## Violation Protocol (Self-Evolution)

When ANY HARD GATE is violated:

1. **STOP** all implementation immediately
2. **Self-critique report**:
   ```
   VIOLATION: HG-[N] [gate name]
   WHAT I DID: [specific action that violated the gate]
   WHY IT HAPPENED: [root cause of the violation]
   DAMAGE: [what might be wrong as a result]
   ```
3. **Collect facts**: Logs, user input, web research
4. **New plan**: Create a plan that starts from verified facts
5. **Record lesson**: Save to memory `feedback_*.md` (Reflexion memorize pattern)

---

## Rationalizations to Reject

Full reference with 17 patterns + Self-Check Protocol:
→ `references/rationalizations-to-reject.md`

Summary (8 most common):

| Rationalization | Required Action |
|----------------|-----------------|
| "Playwright passed, so it works" | Real device check or ask user |
| "I wrote the fix, so it's fixed" | Server logs + browser verification |
| "Same approach, minor tweak" | Abandon hypothesis, list 3 alternatives |
| "Research says this is the solution" | `node -e` test or real device test |
| "forge_ace PASS = quality OK" | Browser visual check |
| "Just this once, skip the check" | Never skip. Pause session if tired |
| "Tests cover this already" | Walk through as a user |
| "It worked last time" | Fresh build (`rm -rf .next`) |

---

## Quick Reference Card

```
STEP 0 — ACTIVATE:
  [ ] Verify GATEKEEPER_SESSION_DIR is set (BLOCK if not)
  [ ] Create {project}/.gatekeeper/session.json (v1.2)
  [ ] Auto-migrate from /tmp/.gatekeeper-session.json if exists
  [ ] Determine mode: paired (with forge_ace) or standalone

STEP 1 — RESEARCH (HG-1):
  [ ] Read designs/ + Figma screenshot + existing patterns
  [ ] Checklist: checklists/pre-implementation.md

STEP 1.5 — UX PROTOCOL (HG-1.5, mandatory all modes):
  [ ] SCREEN / USER GOAL / FIRST ACTION
  [ ] HAPPY PATH / ERROR PATH / EDGE CASES

STEP 2 — CONSISTENCY (HG-2):
  [ ] Grep existing components before creating new ones
  [ ] DS tokens only (colors, shadows, touch 44px+)
  [ ] Minimal fix first (1-line > rewrite)
  [ ] Research validation: checklists/research-validation.md

STEP 3 — FACTS (HG-3, always active):
  [ ] Facts first (logs, console, network, dashboard)
  [ ] External API: node -e test before integrating

STEP 4 — HYPOTHESIS (HG-4, requires HG-3 first):
  [ ] HG-3 must be PASS before HG-4 activates
  [ ] Max 2 attempts per hypothesis, then abandon
  [ ] 3 alternative hypotheses before retry
  [ ] Skip: Pure UI-only with zero external API calls and no debugging (skips both HG-3+HG-4)

STEP 5 — VERIFY (HG-5):
  [ ] Self-Check Protocol (5 questions)
  [ ] rm -rf .next && build && verify in browser
  [ ] Report: VERIFIED / BUILT / TESTED / NEEDS_USER
  [ ] Request user device check if mobile-specific
```

---

## References

- `references/failure-patterns.md` — 11 categories, 50+ incidents from v28-v36
- `references/rationalizations-to-reject.md` — 17 AI rationalization patterns + Self-Check Protocol
- `checklists/pre-implementation.md` — HG-1 + UX Protocol combined checklist
- `checklists/research-validation.md` — Category 8 (research without validation) prevention

## File Structure

```
~/.claude/skills/gatekeeper/
├── SKILL.md                          <- This file (v1.2, Step 0-5 + 1.5)
├── references/
│   ├── failure-patterns.md           <- 11 categories, 50+ incidents
│   └── rationalizations-to-reject.md <- 17 patterns + Self-Check Protocol
├── checklists/
│   ├── pre-implementation.md         <- HG-1 + UX Protocol combined
│   └── research-validation.md        <- Category 8 prevention
├── tests/
│   ├── test-gate-compliance.sh       <- Gate application verification
│   └── test-hooks.sh                 <- Hook behavior verification
└── test-scenarios/
    ├── scenario-new-screen.md        <- New screen implementation
    ├── scenario-bug-fix.md           <- Bug fix with hypothesis tracking
    └── scenario-api-integration.md   <- External API integration

{project_root}/.gatekeeper/           <- Per-project session data (gitignored)
├── session.json                      <- Active session
└── history/                          <- Completed sessions (max 3)
    └── {ISO-timestamp}.json
```
