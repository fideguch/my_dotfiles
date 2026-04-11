# Rationalizations to Reject

> Based on trailofbits/skills fp-check pattern (4,466+ stars)
> + verification-before-completion Rationalization Prevention
> + kireinavi project failure patterns (v28-v36, 50+ incidents)

## How to Use This Document

When you are about to make a claim, check if any of these rationalizations are influencing your judgment.
If you recognize one, STOP and follow the Required Action.

---

## Completion Rationalizations

| # | Rationalization | Why It's Wrong | Required Action |
|---|----------------|----------------|-----------------|
| R1 | "Playwright tests pass, so it works" | Playwright runs Chromium, not iOS Safari. `inert` attribute, HMR WebSocket, Cookie secure flags all behave differently. Test env != prod env | Run on real device OR ask user to verify |
| R2 | "I wrote the fix, so it's fixed" | Code change != behavior change. Build cache may serve old code. Import may be missing. Runtime env may differ | Server logs + browser verification with fresh build |
| R3 | "Build succeeds, so it's correct" | Build checks syntax, not semantics. Hydration errors, runtime crashes, missing data all pass build | Open in browser, walk through user flow |
| R4 | "curl returns 200, so the page works" | Server HTML response != client-side hydration + interaction. React errors happen after initial response | Open in browser, check console for errors |
| R5 | "Tests cover this already" | Tests verify logic (assertions), not experience (can user actually tap this button on mobile?) | Walk through as a user in browser |
| R6 | "forge_ace PASS = quality OK" | forge_ace checks code structure, logic flow, component composition. Does NOT check: actual tap working, form submission end-to-end, visual spacing | Browser visual check after SHIP |

---

## Debugging Rationalizations

| # | Rationalization | Why It's Wrong | Required Action |
|---|----------------|----------------|-----------------|
| R7 | "Same approach, minor tweak will fix it" | Fixation Bias (ACM CB3). If the direction is wrong, refinement within that direction won't help | Abandon hypothesis after 2 failures. List 3 alternatives |
| R8 | "Research says this is the solution" | Blog posts, Stack Overflow, docs are secondary sources. API behavior changes. Version differences exist | `node -e` test or real device test before implementing |
| R9 | "This library handles it (mobile-friendly)" | Library claims != verified behavior on target device. react-image-crop "mobile support" != tested on iOS Safari | Test on actual target device before committing |
| R10 | "The error message says X, so X is the cause" | Error messages describe symptoms, not root causes. Stripe "card declined" can mean missing Cookie, not card issue | Trace the full request path. Check all intermediate steps |
| R11 | "It worked last time" | Caches (.next), env changes (expired keys), stale builds, port conflicts all invalidate "last time" | Fresh build: `rm -rf .next && npm run build` |

---

## Process Rationalizations

| # | Rationalization | Why It's Wrong | Required Action |
|---|----------------|----------------|-----------------|
| R12 | "I already read the designs" | Memory of docs != current content. Specs update. You may have missed a section | Re-read the specific section at decision time. Grep, don't recall |
| R13 | "This is a small change, skip the checks" | Small changes cause cascading failures (v34: missing import crashed 2 pages) | Same gates apply regardless of change size |
| R14 | "I'll verify later / in the next step" | "Later" never comes. Debt compounds. Next step assumes this step is verified | Verify NOW before moving on |
| R15 | "The user didn't ask me to check this" | Professional responsibility. User expects working code, not "you didn't ask me to test" | Always verify. Report status honestly (VERIFIED vs BUILT) |
| R16 | "I'm confident this is correct" | Confidence is not evidence. 10+ Stripe failures were each "confident" fixes | Run the verification command. Show the output |
| R17 | "Just this once, I'll skip verification" | One skip = precedent for the next skip. Quality collapses exponentially | Never skip. If tired, pause the session |

---

## Self-Check Protocol

Before ANY completion claim, ask yourself:

```
1. Am I using any word from {should, probably, seems, likely, confident}?
   -> If YES: I don't have evidence. Get evidence.

2. Am I basing this on a test runner output (Playwright, vitest, build)?
   -> If YES: That's a CODE test, not a USER test. Open browser.

3. Am I on my 3rd+ attempt at the same approach?
   -> If YES: I'm fixated. Stop. List 3 alternative hypotheses.

4. Am I relying on memory of a file I read earlier?
   -> If YES: Re-read the specific section now.

5. Did I actually open a browser / ask user to verify?
   -> If NO: I cannot claim VERIFIED. Use BUILT or TESTED status.
```
