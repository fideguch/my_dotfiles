#!/usr/bin/env bash
set -euo pipefail

# test-hooks.sh — Tests for gatekeeper hooks
# Verifies HG-1 pre-edit guard, HG-5 stop check, and session rotate behavior.
# Uses GATEKEEPER_SESSION_DIR env var for session path resolution.

GUARD_HOOK="$HOME/my_dotfiles/claude/scripts/hooks/gatekeeper-pre-edit-guard.js"
STOP_HOOK="$HOME/my_dotfiles/claude/scripts/hooks/gatekeeper-stop-check.js"
ROTATE_HOOK="$HOME/my_dotfiles/claude/scripts/hooks/gatekeeper-session-rotate.js"
TEST_SESSION_DIR="/tmp/.gatekeeper-hook-test-$$"
GATEKEEPER_DIR="$TEST_SESSION_DIR/.gatekeeper"
SESSION_FILE="$GATEKEEPER_DIR/session.json"
HISTORY_DIR="$GATEKEEPER_DIR/history"
PASSED=0
FAILED=0
TOTAL=14

if ! which node >/dev/null 2>&1; then
  echo "SKIP: node not found"
  exit 0
fi

setup() {
  mkdir -p "$GATEKEEPER_DIR"
}

cleanup() {
  rm -rf "$TEST_SESSION_DIR"
}

write_session() {
  mkdir -p "$GATEKEEPER_DIR"
  cat > "$SESSION_FILE" << EOF
$1
EOF
}

assert_exit() {
  local test_name="$1"
  local expected_exit="$2"
  local actual_exit="$3"
  if [ "$expected_exit" = "$actual_exit" ]; then
    echo "PASS: $test_name"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL: $test_name (expected exit $expected_exit, got $actual_exit)"
    FAILED=$((FAILED + 1))
  fi
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

# --- Pre-Edit Guard Tests ---

# Test 1: No session file → allow (exit 0)
cleanup
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" TOOL_INPUT='{"file_path":"/Users/test/project/src/app/page.tsx"}' node "$GUARD_HOOK" 2>/dev/null
assert_exit "No session file → allow" "0" "$?"

# Test 2: HG-1 pending + src/ edit → block (exit 2)
write_session '{"version":"1.2","project_dir":"/tmp/test","mode":"paired","gates":{"hg1":{"status":"pending","evidence":null},"hg1_5":{"status":"pending","evidence":null},"hg2":{"status":"pending","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
EXIT_CODE=0
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" TOOL_INPUT='{"file_path":"/Users/test/project/src/app/page.tsx"}' node "$GUARD_HOOK" 2>/dev/null || EXIT_CODE=$?
assert_exit "HG-1 pending + src/ edit → block" "2" "$EXIT_CODE"

# Test 3: HG-1 PASS + src/ edit → allow (exit 0)
write_session '{"version":"1.2","project_dir":"/tmp/test","mode":"paired","gates":{"hg1":{"status":"PASS","evidence":"designs/fr.md"},"hg1_5":{"status":"pending","evidence":null},"hg2":{"status":"pending","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" TOOL_INPUT='{"file_path":"/Users/test/project/src/components/Button.tsx"}' node "$GUARD_HOOK" 2>/dev/null
assert_exit "HG-1 PASS + src/ edit → allow" "0" "$?"

# Test 4: HG-1 pending + non-src edit (designs/) → allow (exit 0)
write_session '{"version":"1.2","project_dir":"/tmp/test","mode":"paired","gates":{"hg1":{"status":"pending","evidence":null},"hg1_5":{"status":"pending","evidence":null},"hg2":{"status":"pending","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" TOOL_INPUT='{"file_path":"/Users/test/project/designs/requirements.md"}' node "$GUARD_HOOK" 2>/dev/null
assert_exit "HG-1 pending + designs/ edit → allow" "0" "$?"

# Test 5: HG-1 skipped (standalone mode) + src/ edit → allow (exit 0)
write_session '{"version":"1.2","project_dir":"/tmp/test","mode":"standalone","gates":{"hg1":{"status":"skipped","evidence":null},"hg1_5":{"status":"pending","evidence":null},"hg2":{"status":"skipped","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" TOOL_INPUT='{"file_path":"/Users/test/project/src/lib/stripe.ts"}' node "$GUARD_HOOK" 2>/dev/null
assert_exit "HG-1 skipped (standalone) + src/ edit → allow" "0" "$?"

# --- Stop Check Tests ---

# Test 6: No session file → no warn (exit 0)
cleanup
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" node "$STOP_HOOK" 2>/dev/null
assert_exit "Stop: No session file → no warn" "0" "$?"

# Test 7: Active session + HG-5 pending → warn but exit 0
write_session '{"version":"1.2","project_dir":"/tmp/test","mode":"paired","gates":{"hg1":{"status":"PASS","evidence":"ok"},"hg1_5":{"status":"PASS","evidence":"ok"},"hg2":{"status":"PASS","evidence":null},"hg3":{"status":"skipped","evidence":null},"hg4":{"status":"skipped","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
WARN_OUTPUT=$(GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" node "$STOP_HOOK" 2>&1)
assert_exit "Stop: Active session + HG-5 pending → exit 0 (warn only)" "0" "$?"

# Test 8: Complete session → no warn (exit 0)
write_session '{"version":"1.2","project_dir":"/tmp/test","mode":"paired","gates":{"hg1":{"status":"PASS","evidence":"ok"},"hg1_5":{"status":"PASS","evidence":"ok"},"hg2":{"status":"PASS","evidence":null},"hg3":{"status":"skipped","evidence":null},"hg4":{"status":"skipped","attempts":[]},"hg5":{"status":"PASS","verdict":"VERIFIED"}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":"VERIFIED"}'
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" node "$STOP_HOOK" 2>/dev/null
assert_exit "Stop: Complete session → no warn" "0" "$?"

# --- Session Rotate Tests ---

# Test 9: No session file → no rotation (exit 0)
cleanup
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" node "$ROTATE_HOOK" 2>/dev/null
assert_exit "Rotate: No session file → exit 0" "0" "$?"

# Test 10: Incomplete session (final_status null) → no rotation
write_session '{"version":"1.2","project_dir":"/tmp/test","mode":"paired","gates":{"hg1":{"status":"PASS","evidence":"ok"},"hg1_5":{"status":"PASS","evidence":"ok"},"hg2":{"status":"PASS","evidence":null},"hg3":{"status":"skipped","evidence":null},"hg4":{"status":"skipped","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" node "$ROTATE_HOOK" 2>/dev/null
assert_exit "Rotate: Incomplete session → no rotation" "0" "$?"
# Verify session.json still exists
if [ -f "$SESSION_FILE" ]; then
  echo "PASS: Rotate: session.json preserved when incomplete"
  PASSED=$((PASSED + 1))
else
  echo "FAIL: Rotate: session.json should exist when incomplete"
  FAILED=$((FAILED + 1))
fi

# Test 11 (was assert above)

# Test 12: Complete session → rotated to history
write_session '{"version":"1.2","project_dir":"/tmp/test","mode":"paired","gates":{"hg1":{"status":"PASS","evidence":"ok"},"hg1_5":{"status":"PASS","evidence":"ok"},"hg2":{"status":"PASS","evidence":null},"hg3":{"status":"skipped","evidence":null},"hg4":{"status":"skipped","attempts":[]},"hg5":{"status":"PASS","verdict":"VERIFIED"}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":"VERIFIED"}'
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" node "$ROTATE_HOOK" 2>/dev/null
if [ ! -f "$SESSION_FILE" ] && [ -d "$HISTORY_DIR" ] && [ "$(ls -1 "$HISTORY_DIR" | wc -l | tr -d ' ')" = "1" ]; then
  echo "PASS: Rotate: session moved to history"
  PASSED=$((PASSED + 1))
else
  echo "FAIL: Rotate: session should be moved to history"
  FAILED=$((FAILED + 1))
fi

# Test 13: History pruning keeps max 3
for i in 1 2 3 4; do
  write_session "{\"version\":\"1.2\",\"project_dir\":\"/tmp/test\",\"mode\":\"paired\",\"gates\":{\"hg1\":{\"status\":\"PASS\",\"evidence\":\"ok\"},\"hg1_5\":{\"status\":\"PASS\",\"evidence\":\"ok\"},\"hg2\":{\"status\":\"PASS\",\"evidence\":null},\"hg3\":{\"status\":\"skipped\",\"evidence\":null},\"hg4\":{\"status\":\"skipped\",\"attempts\":[]},\"hg5\":{\"status\":\"PASS\",\"verdict\":\"VERIFIED\"}},\"hypothesis_tracker\":{\"current\":null,\"failed\":[],\"attempt_count\":0},\"final_status\":\"VERIFIED\"}"
  sleep 0.1
  GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" node "$ROTATE_HOOK" 2>/dev/null
done
HISTORY_COUNT=$(ls -1 "$HISTORY_DIR" 2>/dev/null | wc -l | tr -d ' ')
assert_eq "Rotate: History pruned to max 3" "3" "$HISTORY_COUNT"

# Test 14: Hypothesis tracker failed array capped at 10
MANY_FAILED=$(python3 -c "import json; print(json.dumps(['h'+str(i) for i in range(15)]))")
write_session "{\"version\":\"1.2\",\"project_dir\":\"/tmp/test\",\"mode\":\"paired\",\"gates\":{\"hg1\":{\"status\":\"PASS\",\"evidence\":\"ok\"},\"hg1_5\":{\"status\":\"PASS\",\"evidence\":\"ok\"},\"hg2\":{\"status\":\"PASS\",\"evidence\":null},\"hg3\":{\"status\":\"PASS\",\"evidence\":\"ok\"},\"hg4\":{\"status\":\"PASS\",\"attempts\":[]},\"hg5\":{\"status\":\"pending\",\"verdict\":null}},\"hypothesis_tracker\":{\"current\":null,\"failed\":$MANY_FAILED,\"attempt_count\":15},\"final_status\":null}"
GATEKEEPER_SESSION_DIR="$TEST_SESSION_DIR" node "$ROTATE_HOOK" 2>/dev/null
FAILED_COUNT=$(cat "$SESSION_FILE" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['hypothesis_tracker']['failed']))")
assert_eq "Rotate: Failed hypotheses capped at 10" "10" "$FAILED_COUNT"

# --- Summary ---
cleanup
echo ""
echo "================================"
echo "Results: $PASSED/$TOTAL passed, $FAILED failed"
echo "================================"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
