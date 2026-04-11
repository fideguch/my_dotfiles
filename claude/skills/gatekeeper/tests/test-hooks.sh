#!/usr/bin/env bash
set -euo pipefail

# test-hooks.sh — Tests for gatekeeper hooks
# Verifies HG-1 pre-edit guard and HG-5 stop check behavior.

GUARD_HOOK="$HOME/my_dotfiles/claude/scripts/hooks/gatekeeper-pre-edit-guard.js"
STOP_HOOK="$HOME/my_dotfiles/claude/scripts/hooks/gatekeeper-stop-check.js"
SESSION_FILE="/tmp/.gatekeeper-session.json"
PASSED=0
FAILED=0
TOTAL=8

if ! which node >/dev/null 2>&1; then
  echo "SKIP: node not found"
  exit 0
fi

cleanup() {
  rm -f "$SESSION_FILE"
}

write_session() {
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

# --- Pre-Edit Guard Tests ---

# Test 1: No session file → allow (exit 0)
cleanup
TOOL_INPUT='{"file_path":"/Users/test/project/src/app/page.tsx"}' node "$GUARD_HOOK" 2>/dev/null
assert_exit "No session file → allow" "0" "$?"

# Test 2: HG-1 pending + src/ edit → block (exit 2)
write_session '{"version":"1.1","mode":"paired","gates":{"hg1":{"status":"pending","evidence":null},"hg2":{"status":"pending","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
EXIT_CODE=0
TOOL_INPUT='{"file_path":"/Users/test/project/src/app/page.tsx"}' node "$GUARD_HOOK" 2>/dev/null || EXIT_CODE=$?
assert_exit "HG-1 pending + src/ edit → block" "2" "$EXIT_CODE"

# Test 3: HG-1 PASS + src/ edit → allow (exit 0)
write_session '{"version":"1.1","mode":"paired","gates":{"hg1":{"status":"PASS","evidence":"designs/fr.md"},"hg2":{"status":"pending","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
TOOL_INPUT='{"file_path":"/Users/test/project/src/components/Button.tsx"}' node "$GUARD_HOOK" 2>/dev/null
assert_exit "HG-1 PASS + src/ edit → allow" "0" "$?"

# Test 4: HG-1 pending + non-src edit (designs/) → allow (exit 0)
write_session '{"version":"1.1","mode":"paired","gates":{"hg1":{"status":"pending","evidence":null},"hg2":{"status":"pending","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
TOOL_INPUT='{"file_path":"/Users/test/project/designs/requirements.md"}' node "$GUARD_HOOK" 2>/dev/null
assert_exit "HG-1 pending + designs/ edit → allow" "0" "$?"

# Test 5: HG-1 skipped (standalone mode) + src/ edit → allow (exit 0)
write_session '{"version":"1.1","mode":"standalone","gates":{"hg1":{"status":"skipped","evidence":null},"hg2":{"status":"skipped","evidence":null},"hg3":{"status":"pending","evidence":null},"hg4":{"status":"pending","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
TOOL_INPUT='{"file_path":"/Users/test/project/src/lib/stripe.ts"}' node "$GUARD_HOOK" 2>/dev/null
assert_exit "HG-1 skipped (standalone) + src/ edit → allow" "0" "$?"

# --- Stop Check Tests ---

# Test 6: No session file → no warn (exit 0)
cleanup
node "$STOP_HOOK" 2>/dev/null
assert_exit "Stop: No session file → no warn" "0" "$?"

# Test 7: Active session + HG-5 pending → warn but exit 0
write_session '{"version":"1.1","mode":"paired","gates":{"hg1":{"status":"PASS","evidence":"ok"},"hg2":{"status":"PASS","evidence":null},"hg3":{"status":"skipped","evidence":null},"hg4":{"status":"skipped","attempts":[]},"hg5":{"status":"pending","verdict":null}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":null}'
WARN_OUTPUT=$(node "$STOP_HOOK" 2>&1)
assert_exit "Stop: Active session + HG-5 pending → exit 0 (warn only)" "0" "$?"

# Test 8: Complete session → no warn (exit 0)
write_session '{"version":"1.1","mode":"paired","gates":{"hg1":{"status":"PASS","evidence":"ok"},"hg2":{"status":"PASS","evidence":null},"hg3":{"status":"skipped","evidence":null},"hg4":{"status":"skipped","attempts":[]},"hg5":{"status":"PASS","verdict":"VERIFIED"}},"hypothesis_tracker":{"current":null,"failed":[],"attempt_count":0},"final_status":"VERIFIED"}'
node "$STOP_HOOK" 2>/dev/null
assert_exit "Stop: Complete session → no warn" "0" "$?"

# --- Summary ---
cleanup
echo ""
echo "================================"
echo "Results: $PASSED/$TOTAL passed, $FAILED failed"
echo "================================"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
