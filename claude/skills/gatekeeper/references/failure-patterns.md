# Failure Patterns — kireinavi Project (v28-v36)

> Extracted from bochi reflection memos. 11 categories, 50+ incidents.
> Each pattern includes detection signals and prevention gates.

## Category 1: Guess-Fix Without Verification (8 incidents)

**Pattern**: Fix guessed -> test something unrelated -> declare success -> still broken.

| Session | Incident | Gate |
|---------|----------|------|
| v35 | `modal={false}` -> `showOverlay` -> Playwright PASS -> iOS still broken | HG-3, HG-5 |
| v34 | `useMemo` added without import -> transpile OK -> runtime crash | HG-5 |
| v31 | `bottom-0` -> `bottom-16` -> CSS not reflected in bundle (3 attempts) | HG-4, HG-5 |
| v32 | Stripe error exposure (non-USER error visible to end user) | HG-3 |
| v28 | Zod v4 UUID validation failed 5x on identical `d0000000` seed | HG-4 |
| v30 | Barcode validation insufficient, date format too permissive | HG-3 |
| v36 | Stripe payment 10+ failures, wrong root cause (startTransition vs. secure Cookie) | HG-3, HG-4 |

**Detection signal**: "should work", "probably fixed", "seems correct"
**Prevention**: HG-3 (facts before fix) + HG-5 (device verification)

---

## Category 2: Playwright Pass != Real Device (6 incidents)

**Pattern**: E2E tests pass in Chromium but feature is broken on real devices.

| Session | Incident | Root Cause |
|---------|----------|------------|
| v35 | Playwright tap() PASS, iOS Safari untappable | React `inert` attribute, Playwright bypasses it |
| v28 | 65 E2E tests pass, booking form never submits | Tests check "text visible" not "flow completes" |
| v34 | curl HTTP 200, Client Component hydration crash | Server response OK != client render OK |
| v32 | vitest PASS, 3 bugs on real device | NotificationBell setState, Stripe error, duplicate icon |
| v35 | Playwright hydration OK, WebKit HMR WebSocket fail | Playwright uses localhost (succeeds) vs IP (fails) |
| v35 | Turbopack dev mode OK, production build broken | HMR masks issues that surface in prod build |

**Detection signal**: "tests pass" used as evidence of working
**Prevention**: HG-5 (verify on device, not just test runner)

---

## Category 3: Hypothesis Fixation (5 incidents)

**Pattern**: Lock onto first theory, chase it for 3+ attempts instead of re-examining.

| Session | Wrong Hypothesis | Actual Cause | Attempts |
|---------|-----------------|--------------|----------|
| v35 | PwaInstallSheet structure | Turbopack HMR WebSocket on IP | 4 |
| v28 | router.back() logic | next/link vs button hydration mismatch | 3 |
| v36 | startTransition+redirect | secure:true Cookie on HTTP | 10+ |
| v31 | fixed bottom layout | Existing FixedCTABar with Portal | 3 |
| v30 | locale:"ja" parameter | Express accounts don't support locale | 3 |

**Detection signal**: Same approach attempted 3+ times with minor variations
**Prevention**: HG-4 (abandon after 2 failures, list 3 alternatives)

---

## Category 4: Breaking Existing Features (4 incidents)

**Pattern**: Fix one thing, break something else that was working.

| Session | What Broke | How |
|---------|-----------|-----|
| v35 | PwaInstallSheet component | Rewrote structure (1-line fix was sufficient) |
| v34 | /search page + category page | Missing import statement cascade |
| v29 | Mobile layout | Removed both max-w constraints |
| v30 | Table relationships | New tables without documenting relation to existing |

**Detection signal**: Architectural changes before trying minimal fix
**Prevention**: HG-2 (consistency gate) + minimum viable fix first

---

## Category 5: forge_ace PASS but UX Fails (3 incidents)

**Pattern**: Guardian/Overseer/PM-Admin all PASS, but real user interaction broken.

| Session | What forge_ace Missed |
|---------|----------------------|
| v32 | NotificationBell setState error, Stripe error exposed, duplicate icon |
| v29 | Header-content gap zero, elements too small |
| v30 | Calendar toggle only works one direction |

**Detection signal**: forge_ace SHIP without browser check
**Prevention**: HG-5 (gatekeeper runs AFTER forge_ace SHIP)

---

## Category 6: Design/Spec Reading Skipped (5 incidents)

**Pattern**: Required info was in docs but relied on memory or assumptions.

| Session | What Was Missed | Where It Was |
|---------|----------------|--------------|
| v34 | "What regions?" question | functional_requirements.md line 17 |
| v34 | Real-time search feedback | Airbnb pattern in design docs |
| v30 | Toggle auto-save vs manual save | Settings pattern not confirmed |
| v29 | Provider role redirect | Middleware requirements |
| v27 | Legal page content | designs/ already had it |

**Detection signal**: Asking user a question that's answered in designs/
**Prevention**: HG-1 (read ALL related docs before asking)

---

## Category 7: External API Assumptions (7 incidents)

**Pattern**: Assume API behavior from docs without `node -e` testing.

| Session | API | Assumption | Reality |
|---------|-----|-----------|---------|
| v33 | Stripe Connect | "costs 0 yen" | 275 yen/tx + 220 yen/mo + 0.25% |
| v33 | Stripe | Test account number | Requires `0001234` specifically |
| v33 | Stripe | `type:"custom"` | Deprecated, use Controller Properties |
| v31 | Stripe | `address` field | Japan requires `address_kanji` |
| v31 | Stripe | `locale:"ja"` | Express accounts don't support it |
| v31 | Stripe | Phone format | E.164 required (+8190xxxx) |
| v31 | Stripe | business_profile.url | DNS resolution validated |

**Detection signal**: API integration without `node -e` test
**Prevention**: HG-3 (external API -> always test first)

---

## Category 8: Research Without Validation (4 incidents)

**Pattern**: Competitive research done but not validated against actual requirements.

| Session | Research | Problem |
|---------|----------|---------|
| v30 | Airbnb calendar 24/72h | Required DB changes across 20+ files |
| v34 | Airbnb search UX | Input step vs real-time priority confused |
| v29 | Toggle vs save button | Not confirmed with user |

**Detection signal**: "Based on Airbnb research..." without user confirmation
**Prevention**: Research = input, not decision. Confirm with user.

---

## Category 9: Caching / Stale Build (5 incidents)

**Pattern**: Code changed but old build served. Agent doesn't notice.

| Session | What Happened |
|---------|--------------|
| v35 | Turbopack HMR WebSocket fails on IP, stale chunks served |
| v31 | CSS change not reflected for 5 attempts |
| v28 | Link->button change causes hydration from stale cache |
| v32 | Stale server on port 3000, never killed old PID |
| v36 | STRIPE_KEY expired but Zod only checks format |

**Detection signal**: "Won't update", "still showing old version"
**Prevention**: `rm -rf .next` mandatory before verification (HG-5)

---

## Category 10: Component Non-Reuse (4 incidents)

**Pattern**: Working component exists, new code written instead.

| Session | Existing Component | What Was Built Instead |
|---------|-------------------|----------------------|
| v31 | FixedCTABar (Portal) | New fixed bottom layout |
| v29 | Postal code auto-fill | Duplicate logic in booking |
| v29 | BookingCard | Custom Link rendering |
| v29 | Consumer-side patterns | Rebuilt without checking |

**Detection signal**: Creating new component without grep for existing
**Prevention**: HG-2 (grep before create)

---

## Category 11: No Browser Verification (6 incidents)

**Pattern**: Code merged without opening actual browser.

| Session | What Was Checked | What Was Not |
|---------|-----------------|--------------|
| v34 | curl HTTP 200 | Client hydration |
| v35 | Playwright screenshots | Real tap on iOS |
| v32 | Unit tests | Click bell + notifications load |
| v28 | File exists | router.back() works on each page |
| v36 | Stripe API call succeeds | Full booking flow with cookies |

**Detection signal**: "Verified" without browser-open evidence
**Prevention**: HG-5 (VERIFIED status requires browser evidence)
