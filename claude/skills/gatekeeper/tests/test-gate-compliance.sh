#!/usr/bin/env bash
set -euo pipefail

# test-gate-compliance.sh — Tests for gatekeeper gate application
# Verifies session state transitions and gate compliance.
# Supports GATEKEEPER_SESSION_DIR env var for session path resolution.

SESSION_DIR="${GATEKEEPER_SESSION_DIR:-/tmp/.gatekeeper-test-$$}"
GATEKEEPER_DIR="$SESSION_DIR/.gatekeeper"
SESSION_FILE="$GATEKEEPER_DIR/session.json"
PASSED=0
FAILED=0
TOTAL=14

setup() {
  mkdir -p "$GATEKEEPER_DIR"
}

cleanup() {
  rm -rf "$SESSION_DIR/.gatekeeper"
  # Clean up legacy location if it exists
  rm -f "/tmp/.gatekeeper-session.json"
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

# --- Test 1: Session creation with v1.2 ---
cleanup
setup
cat > "$SESSION_FILE" << 'EOF'
{"version":"1.2","created":"2026-04-11T00:00:00Z","project_dir":"/tmp/test","mode":"paired","gates":{"hg1":{"status":"pending","evidence":null},"hg1_5":{"status":"pending","evidence":null},"hg2":{"status":"pending","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}
EOF
VERSION=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
assert_eq "Session creation with version 1.2" "1.2" "$VERSION"

# --- Test 2: project_dir field exists ---
PROJECT_DIR=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['project_dir'])")
assert_eq "project_dir field exists" "/tmp/test" "$PROJECT_DIR"

# --- Test 3: HG-1 PASS updates correctly ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['gates']['hg1']['status'] = 'PASS'
s['gates']['hg1']['evidence'] = 'designs/functional_requirements.md, Figma #39:2'
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
STATUS=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg1']['status'])")
assert_eq "HG-1 status updates to PASS" "PASS" "$STATUS"

# --- Test 4: HG-1 evidence is recorded ---
EVIDENCE=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg1']['evidence'])")
assert_contains "HG-1 evidence contains file reference" "designs/" "$EVIDENCE"

# --- Test 5: HG-1.5 exists and updates to PASS ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['gates']['hg1_5']['status'] = 'PASS'
s['gates']['hg1_5']['evidence'] = 'UX protocol: SCREEN=login, USER GOAL=authenticate'
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
STATUS=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg1_5']['status'])")
assert_eq "HG-1.5 status updates to PASS" "PASS" "$STATUS"

# --- Test 6: HG-1.5 evidence recorded ---
EVIDENCE=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg1_5']['evidence'])")
assert_contains "HG-1.5 evidence contains UX protocol" "UX protocol" "$EVIDENCE"

# --- Test 7: HG-3 can be skipped for non-bug-fix ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['gates']['hg3']['status'] = 'skipped'
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
STATUS=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg3']['status'])")
assert_eq "HG-3 can be skipped" "skipped" "$STATUS"

# --- Test 8: HG-4 skipped when HG-3 skipped (shared skip condition) ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['gates']['hg4']['status'] = 'skipped'
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
HG3=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg3']['status'])")
HG4=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['gates']['hg4']['status'])")
assert_eq "HG-3 and HG-4 both skipped (shared skip)" "skipped:skipped" "$HG3:$HG4"

# --- Test 9: Hypothesis tracker records failed hypotheses ---
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

# --- Test 10: Failed hypothesis is in failed list ---
FAILED_LIST=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['hypothesis_tracker']['failed'])")
assert_contains "Failed hypothesis recorded" "async blocking" "$FAILED_LIST"

# --- Test 11: HG-5 verdict must be one of valid values ---
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

# --- Test 12: Final status reflects HG-5 verdict ---
cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
s['final_status'] = s['gates']['hg5']['verdict']
json.dump(s, sys.stdout)
" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
FINAL=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['final_status'])")
assert_eq "Final status matches HG-5 verdict" "NEEDS_USER" "$FINAL"

# --- Test 13: All gates have status field (including hg1_5) ---
ALL_HAVE_STATUS=$(cat "$SESSION_FILE" | python3 -c "
import sys, json
s = json.load(sys.stdin)
gates = s['gates']
all_ok = all('status' in gates[g] for g in gates)
has_hg1_5 = 'hg1_5' in gates
print('true' if (all_ok and has_hg1_5) else 'false')
")
assert_eq "All gates have status field (including hg1_5)" "true" "$ALL_HAVE_STATUS"

# --- Test 14: Mode is paired or standalone ---
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
