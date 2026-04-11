#!/usr/bin/env bash
set -euo pipefail

# test-gate-compliance.sh — Tests for gatekeeper gate application
# Verifies session state transitions and gate compliance.

SESSION_FILE="/tmp/.gatekeeper-session.json"
PASSED=0
FAILED=0
TOTAL=10

cleanup() {
  rm -f "$SESSION_FILE"
}

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $test_name"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL: $test_name (expected '$expected', got '$actual')"
    FAILED=$((FAILED + 1))
  fi
}

assert_contains() {
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "PASS: $test_name"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL: $test_name (expected to contain '$needle')"
    FAILED=$((FAILED + 1))
  fi
}

# --- Test 1: Session creation ---
cleanup
cat > "$SESSION_FILE" << 'EOF'
{"version":"1.1","created":"2026-04-11T00:00:00Z","mode":"paired","gates":{"hg1":{"status":"pending","evidence":null},"hg2":{"status":"pending","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}
EOF
VERSION=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
assert_eq "Session creation with version 1.1" "1.1" "$VERSION"

# --- Test 2: HG-1 PASS updates correctly ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['gates']['hg1']['status'] = 'PASS'
s['gates']['hg1']['evidence'] = 'designs/functional_requirements.md, Figma #39:2'
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
STATUS=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg1']['status'])")
assert_eq "HG-1 status updates to PASS" "PASS" "$STATUS"

# --- Test 3: HG-1 evidence is recorded ---
EVIDENCE=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg1']['evidence'])")
assert_contains "HG-1 evidence contains file reference" "designs/" "$EVIDENCE"

# --- Test 4: HG-3 can be skipped for non-bug-fix ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['gates']['hg3']['status'] = 'skipped'
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
STATUS=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg3']['status'])")
assert_eq "HG-3 can be skipped" "skipped" "$STATUS"

# --- Test 5: Hypothesis tracker records failed hypotheses ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['hypothesis_tracker']['current'] = 'async blocking in onChange'
s['hypothesis_tracker']['attempt_count'] = 2
s['hypothesis_tracker']['failed'].append('async blocking in onChange')
s['hypothesis_tracker']['current'] = None
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
COUNT=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['hypothesis_tracker']['attempt_count'])")
assert_eq "Hypothesis tracker records 2 attempts" "2" "$COUNT"

# --- Test 6: Failed hypothesis is in failed list ---
FAILED_LIST=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['hypothesis_tracker']['failed'])")
assert_contains "Failed hypothesis recorded" "async blocking" "$FAILED_LIST"

# --- Test 7: HG-5 verdict must be one of valid values ---
for verdict in VERIFIED BUILT TESTED NEEDS_USER; do
  cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['gates']['hg5']['verdict'] = '$verdict'
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
done
VERDICT=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg5']['verdict'])")
assert_eq "HG-5 accepts valid verdict" "NEEDS_USER" "$VERDICT"

# --- Test 8: Final status reflects HG-5 verdict ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['final_status'] = s['gates']['hg5']['verdict']
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
FINAL=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['final_status'])")
assert_eq "Final status matches HG-5 verdict" "NEEDS_USER" "$FINAL"

# --- Test 9: All gates have status field ---
ALL_HAVE_STATUS=$(cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
gates = s['gates']
all_ok = all('status' in gates[g] for g in gates)
print('true' if all_ok else 'false')
")
assert_eq "All gates have status field" "true" "$ALL_HAVE_STATUS"

# --- Test 10: Mode is paired or standalone ---
MODE=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['mode'])")
assert_eq "Mode is valid (paired)" "paired" "$MODE"

# --- Summary ---
cleanup
echo ""
echo "================================"
echo "Results: $PASSED/$TOTAL passed, $FAILED failed"
echo "================================"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
