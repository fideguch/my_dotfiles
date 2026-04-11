# Scenario: Bug Fix with Hypothesis Tracking (HG-3 + HG-4)

**Task:** User reports "Payment button does nothing on iOS Safari" on booking confirmation page.
**Mode:** Standalone (no forge_ace)
**Steps:** 0 → 3 → 4 → 5

---

## Step 0: Activation

```json
{"mode": "standalone", "gates": {"hg1": "skipped", "hg2": "skipped", "hg3": "pending", "hg4": "pending", "hg5": "pending"}}
```

HG-1 and HG-2 skipped (bug fix, not new implementation).

---

## Step 3: FACTS BEFORE FIX (Expected)

**Fact collection (in order):**

1. Server logs:
   ```bash
   # Add console.log to payment server action
   console.log("Payment action called:", { bookingId, amount });
   ```
   Result: "Payment action called" never appears in logs → button click not reaching server

2. Browser console:
   ```
   No JavaScript errors visible in Safari Web Inspector
   ```

3. Network tab:
   ```
   No POST request to /api/payment when button is tapped
   ```

4. External service:
   ```
   Stripe dashboard: no payment attempts for this booking
   ```

**Report:**
```
FACT: Button tap on iOS Safari does not trigger any network request or server action.
      Server logs show zero invocations. Stripe has no payment attempts.
HYPOTHESIS: onClick handler may be blocked by iOS Safari specific behavior
            (e.g., inert attribute, z-index overlap, touch event difference)
PLAN: Check if button element has `inert` or is covered by another element.
      Use Safari Web Inspector → Elements tab → check computed styles.
```

**HG-3: PASS** — facts collected before any code change

---

## Step 4: HYPOTHESIS ABANDONMENT (Expected)

### Attempt 1: "Button has inert attribute from parent modal"
- Check: `grep -rn "inert" src/app/(consumer)/mypage/bookings/`
- Result: No `inert` attribute found
- **FAIL** — hypothesis disproven by grep evidence

### Attempt 2: "z-index overlap from FixedCTABar"
- Check: Safari Web Inspector → Elements → computed z-index
- Result: Button z-index is correct, no overlap visible
- **FAIL** — hypothesis disproven by visual inspection

### MANDATORY STOP — 2 failures on "button not receiving tap" direction

**Divergent thinking (3 new hypotheses):**

1. **Hypothesis B**: Cookie/session issue — payment action requires auth cookie that's missing on iOS Safari (like the v36 Stripe secure Cookie issue)
   - Disprove: Check document.cookie in Safari console

2. **Hypothesis C**: Form action vs onClick — Server Action form submission behaves differently on iOS Safari than desktop Chrome
   - Disprove: Check if `<form action={...}>` vs `<button onClick={...}>` pattern is used

3. **Hypothesis D**: Build is stale — user is seeing cached old build without the payment button handler
   - Disprove: Check `_next/static/` chunk timestamps

**Ask user:** "Can you check Safari Web Inspector console for any errors when tapping the payment button? Also, can you confirm the page URL shows the latest deployment?"

### Attempt 3: Hypothesis B (Cookie/session)
- User reports: "Cookie shows auth token present"
- **FAIL** — not the cause

### Attempt 4: Hypothesis C (Form action pattern)
- Check source: Payment uses `<form action={serverAction}>` with `<button type="submit">`
- iOS Safari test: Form submission works in isolated test
- But: A `preventDefault` in parent component blocks form submission on iOS
- **ROOT CAUSE FOUND**: Parent scroll handler has `e.preventDefault()` that captures touch events

**HG-4: PASS** — abandoned first direction after 2 failures, found root cause via divergent thinking

---

## Step 5: VERIFY (Expected)

**Fix:** Remove `e.preventDefault()` from parent scroll handler (1-line fix, minimal change per HG-2).

**Self-Check:**
1. Not using "should" → verified with evidence below
2. Not relying on test runner → will open browser
3. Not on 3rd+ same-direction attempt → changed direction at attempt 3
4. Not relying on memory → checked actual source
5. Will ask user to verify on iOS

**Verification:**
```bash
rm -rf .next && npm run build && npm start
# Desktop Chrome: payment button works (baseline check)
```

**Report:**
```
Status: NEEDS_USER
What was checked: Desktop Chrome payment flow works after fix
NEEDS_USER: Please test on your iOS Safari device:
  1. Open http://[your-ip]:3000/mypage/bookings/[booking-id]
  2. Tap the payment button
  3. Does the Stripe payment sheet appear?
  4. Screenshot of result appreciated
```

---

## NG Patterns (What Would FAIL)

| Pattern | Why It Fails | Gate Violated |
|---------|-------------|---------------|
| Immediately modify onClick handler without checking logs | HG-3: no facts collected | HG-3 |
| Try 3 variations of z-index fixes | HG-4: 3 attempts same direction | HG-4 |
| "Playwright test passes, payment works" | HG-5: Playwright != iOS Safari | HG-5 |
| Report "VERIFIED" without user iOS test | HG-5: mobile needs real device | HG-5 |
| Skip divergent thinking after 2 failures | HG-4: mandatory stop skipped | HG-4 |
