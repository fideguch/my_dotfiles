# Scenario: New Screen Implementation (All Steps)

**Task:** Implement provider booking detail screen (#17-d) with status timeline, action buttons, and chat link.
**Mode:** Paired with forge_ace Full
**Steps:** 0 → 1 → 2 → (forge_ace Writer/Guardian/Overseer/PM) → 5

---

## Step 0: Activation

```json
{"mode": "paired", "gates": {"hg1": "pending", "hg2": "pending", "hg3": "skipped", "hg4": "skipped", "hg5": "pending"}}
```

HG-3 and HG-4 skipped (pure UI implementation — no external API calls, no bug fix).
Note: If this screen required external API integration (e.g., Stripe, Supabase RPC), HG-3 would be active.

---

## Step 1: RESEARCH (Expected)

**Agent reads:**
- designs/functional_requirements.md (FR for booking detail)
- designs/component-definitions.md (BookingCard, StatusTimeline, FixedCTABar)
- designs/design-system.md (tokens)

**Agent calls:**
- Figma get_design_context for screen #17-d

**Agent greps:**
- `grep -rl "BookingDetail" src/app/` → finds consumer version at `src/app/(consumer)/mypage/bookings/[id]/`
- `grep -rl "StatusTimeline" src/components/` → finds existing component

**UX Protocol output:**
```
SCREEN: Provider Booking Detail (#17-d)
USER GOAL: View booking details and take action (confirm/reject/complete)
FIRST ACTION: Read booking status and customer info
HAPPY PATH: Open detail → Read info → Tap "Confirm" → Success toast → Status updates
ERROR PATH: Network error → Retry button. Already cancelled → Disabled actions with explanation
EDGE CASES: Booking just cancelled by customer, concurrent status change
```

**HG-1: PASS** — all docs read, Figma checked, existing patterns found

---

## Step 2: CONSISTENCY (Expected)

**Component reuse:**
- StatusTimeline: EXISTS in src/components/domain/ → REUSE
- FixedCTABar: EXISTS → REUSE with provider-specific actions
- BookingCard: EXISTS → REUSE for summary section

**DS compliance:**
- Colors: semantic tokens only (primary, success, warning, error)
- Touch targets: all buttons min-h-[44px]
- Shadow: SM on cards, MD on bottom bar
- Layout: GlobalHeader + scroll content + FixedCTABar (matches Phase 3 pattern)

**HG-2: PASS** — no new components needed, DS compliant

---

## Step 5: VERIFY (Expected)

**Self-Check:**
1. Not using "should" or "probably" → PASS
2. Not relying only on test runner → will open browser → PASS
3. Not on 3rd+ attempt → N/A (new screen)
4. Not relying on memory → re-read designs/ at decision points → PASS
5. Will open browser → PASS

**Verification:**
```bash
rm -rf .next && npm run build && npm start
# Open http://localhost:3000/partner/bookings/[id]
# Walk through: view detail → confirm → check toast → check status update
```

**Report:**
```
Status: VERIFIED
What was checked: Provider booking detail screen at /partner/bookings/test-id
- Layout matches Figma #17-d
- StatusTimeline shows correct phases
- Confirm button works, toast appears
- Status updates after action
NEEDS_USER: iOS Safari tap target check on action buttons
```

---

## NG Patterns (What Would FAIL)

| Pattern | Why It Fails | Gate Violated |
|---------|-------------|---------------|
| Skip designs/ reading, implement from memory | HG-1: no evidence of docs read | HG-1 |
| Create new StatusTimeline instead of reusing | HG-2: component non-reuse | HG-2 |
| Use custom colors not in design-system.md | HG-2: DS token violation | HG-2 |
| Report "VERIFIED" without opening browser | HG-5: false verification claim | HG-5 |
| Report "Tests pass" as completion evidence | HG-5: Playwright != device | HG-5 |
