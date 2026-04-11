# Scenario: External API Integration (HG-3 Focus)

**Task:** Integrate Stripe Connect onboarding for provider registration.
**Mode:** Paired with forge_ace Full
**Steps:** 0 → 1 → 3 → 2 → (forge_ace) → 5

---

## Step 0: Activation

```json
{"mode": "paired", "gates": {"hg1": "pending", "hg2": "pending", "hg3": "pending", "hg4": "pending", "hg5": "pending"}}
```

All gates active — API integration requires HG-3 (facts before integrating external API).

---

## Step 1: RESEARCH (Expected)

**Agent reads:**
- designs/functional_requirements.md (FR for provider onboarding)
- designs/non_functional_requirements.md (Stripe integration requirements)

**Agent greps:**
- `grep -rl "Stripe" src/lib/` → finds existing Stripe client setup
- `grep -rl "Connect" src/` → finds existing Connect patterns

**HG-1: PASS**

---

## Step 3: FACTS BEFORE FIX — API Verification (Expected)

**CRITICAL: Test API behavior before writing integration code.**

1. **Stripe Connect account creation test:**
   ```bash
   node -e "
   const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
   stripe.accounts.create({
     type: 'express',
     country: 'JP',
     capabilities: { transfers: { requested: true } },
     business_type: 'individual',
     business_profile: { mcc: '7349', url: 'https://kireinavi.jp' }
   }).then(a => console.log('OK:', a.id)).catch(e => console.log('ERROR:', e.message));
   "
   ```
   Result: Verify account creation succeeds with Japan-specific params

2. **Onboarding link generation test:**
   ```bash
   node -e "
   const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
   stripe.accountLinks.create({
     account: 'acct_xxx',
     refresh_url: 'http://localhost:3000/partner/apply/register?refresh=true',
     return_url: 'http://localhost:3000/partner/apply/register?success=true',
     type: 'account_onboarding'
   }).then(l => console.log('URL:', l.url)).catch(e => console.log('ERROR:', e.message));
   "
   ```
   Result: Verify link generation and URL format

3. **Japan-specific field verification:**
   ```bash
   node -e "
   // Test: Does address_kanji work? Does address (Latin) fail?
   const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
   stripe.accounts.update('acct_xxx', {
     individual: {
       address_kanji: { postal_code: '1500001', state: '東京都', city: '渋谷区', town: '神宮前', line1: '1-1-1' }
     }
   }).then(() => console.log('address_kanji: OK')).catch(e => console.log('address_kanji ERROR:', e.message));
   "
   ```
   Result: Confirm Japan requires `address_kanji`, not `address`

4. **Phone format verification:**
   ```bash
   node -e "
   // Test E.164 format requirement
   console.log('090-1234-5678'.replace(/[-\s]/g, '').replace(/^0/, '+81'));
   // Expected: +819012345678
   "
   ```

**Discovered facts (record before implementing):**
```
FACT: Stripe Connect Japan requires:
  - address_kanji (not address) for Japanese addresses
  - E.164 phone format (+81...)
  - business_type: 'individual' for sole proprietors
  - mcc: '7349' for cleaning services
  - Controller Properties (not type: 'custom' which is deprecated)
```

**HG-3: PASS** — all API behaviors verified with `node -e` before implementation

---

## Step 4: HYPOTHESIS ABANDONMENT (If API test fails)

If `node -e` test returns unexpected error:

### Example: Account creation returns "invalid parameter"

**Attempt 1**: Hypothesis "business_type is wrong"
- Test: Change `business_type: 'individual'` to `'company'`
- Result: Same error → FAIL

**Attempt 2**: Hypothesis "business_type needs to match `capabilities`"
- Test: Add `card_payments` capability
- Result: Same "invalid parameter" error → FAIL → **MANDATORY STOP**

**Divergent thinking:**
- Hypothesis B: The `type: 'express'` field is deprecated (use Controller Properties)
- Hypothesis C: Japan requires `tos_acceptance` before account creation
- Hypothesis D: API key doesn't have Connect permissions

**Attempt 3**: Hypothesis B — check Stripe changelog
- Result: Controller Properties is the new API. Root cause found.

**HG-4: PASS** — abandoned after 2 failures, found root cause via divergent thinking

---

## Step 2: CONSISTENCY (Expected)

**Existing patterns to reuse:**
- `src/lib/stripe.ts` — existing Stripe client initialization
- `src/lib/stripe-connect.ts` — existing Connect helper (if any)
- Address format: existing `address_kanji` conversion in profile forms

**HG-2: PASS**

---

## Step 5: VERIFY (Expected)

**Self-Check:** All 5 questions answered with evidence.

**Verification:**
```bash
rm -rf .next && npm run build && npm start
# 1. Navigate to /partner/apply/register
# 2. Fill in provider registration form
# 3. Click "Register" — should redirect to Stripe onboarding
# 4. Complete Stripe test onboarding
# 5. Return to /partner/apply/register?success=true
# 6. Check Supabase: provider record created with stripe_account_id
```

**Report:**
```
Status: VERIFIED
What was checked:
  - Provider registration form submits correctly
  - Stripe onboarding link generated (tested with node -e first)
  - address_kanji format accepted by Stripe (tested with node -e first)
  - Return URL works after Stripe onboarding
  - Provider record in Supabase has correct stripe_account_id
NEEDS_USER: Mobile form usability check on iOS Safari
```

---

## NG Patterns (What Would FAIL)

| Pattern | Why It Fails | Gate Violated |
|---------|-------------|---------------|
| Use `address` instead of `address_kanji` for Japan | HG-3: API not tested with node -e | HG-3 |
| Use `type: 'custom'` (deprecated) | HG-3: would fail if tested | HG-3 |
| Use `locale: 'ja'` for Express accounts | HG-3: Express doesn't support locale | HG-3 |
| Phone as `090-1234-5678` (not E.164) | HG-3: format not verified | HG-3 |
| Assume Stripe Connect is free | HG-3: pricing not checked | HG-3 |
| Skip `node -e` test, go straight to implementation | HG-3: no facts before code | HG-3 |
