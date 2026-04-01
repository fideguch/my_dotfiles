#!/usr/bin/env bash
set -euo pipefail

# test-dispatch-guard.sh — Tests for forge_ace Dispatch Guard Hook
# Verifies agent dispatch sequencing enforcement via session state.

HOOK_PATH="/Users/fumito_ideguchi/my_dotfiles/claude/scripts/hooks/forge-ace-dispatch-guard.js"
SESSION_FILE="/tmp/.forge-ace-session.json"
PASSED=0
FAILED=0
TOTAL=14

# Prereq check
if ! which node >/dev/null 2>&1; then
  echo "SKIP: node not found"
  exit 0
fi

if [ ! -f "$HOOK_PATH" ]; then
  echo "SKIP: hook file not found at $HOOK_PATH"
  exit 0
fi

cleanup() {
  rm -f "$SESSION_FILE"
}

run_hook() {
  local tool_input="$1"
  TOOL_INPUT="$tool_input" node "$HOOK_PATH" 2>/dev/null || true
}

assert_allow() {
  local test_name="$1"
  local output="$2"
  if echo "$output" | grep -q "block"; then
    echo "FAIL: $test_name (expected ALLOW, got BLOCK)"
    FAILED=$((FAILED + 1))
  else
    echo "PASS: $test_name"
    PASSED=$((PASSED + 1))
  fi
}

assert_block() {
  local test_name="$1"
  local output="$2"
  if echo "$output" | grep -q "block"; then
    echo "PASS: $test_name"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL: $test_name (expected BLOCK, got ALLOW)"
    FAILED=$((FAILED + 1))
  fi
}

write_session() {
  local state="$1"
  cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","state":"$state","agents":{}}
SESS
}

# --- Test 1: no_session_file ---
cleanup
OUTPUT=$(run_hook '{"description":"Writer: implement"}')
assert_allow "1. no_session_file" "$OUTPUT"

# --- Test 2: non_forge_agent ---
write_session "INIT"
OUTPUT=$(run_hook '{"description":"Run linter on src/"}')
assert_allow "2. non_forge_agent" "$OUTPUT"
cleanup

# --- Test 3: writer_at_user_confirmed ---
write_session "USER_CONFIRMED"
OUTPUT=$(run_hook '{"description":"Write change-set 1: refactor auth"}')
assert_allow "3. writer_at_user_confirmed" "$OUTPUT"
cleanup

# --- Test 4: writer_at_init ---
write_session "INIT"
OUTPUT=$(run_hook '{"description":"Writer: implement changes"}')
assert_block "4. writer_at_init" "$OUTPUT"
cleanup

# --- Test 5: writer_at_classified ---
write_session "CLASSIFIED"
OUTPUT=$(run_hook '{"description":"Writer: implement changes"}')
assert_block "5. writer_at_classified" "$OUTPUT"
cleanup

# --- Test 6: guardian_at_user_confirmed ---
write_session "USER_CONFIRMED"
OUTPUT=$(run_hook '{"description":"Guardian: verify structural safety"}')
assert_block "6. guardian_at_user_confirmed" "$OUTPUT"
cleanup

# --- Test 7: guardian_at_writer_done ---
write_session "WRITER_DONE"
OUTPUT=$(run_hook '{"description":"Guardian: verify structural safety"}')
assert_allow "7. guardian_at_writer_done" "$OUTPUT"
cleanup

# --- Test 8: overseer_at_guardian_done ---
write_session "GUARDIAN_DONE"
OUTPUT=$(run_hook '{"description":"Overseer: verify requirement alignment"}')
assert_allow "8. overseer_at_guardian_done" "$OUTPUT"
cleanup

# --- Test 9: pm_admin_at_overseer_done ---
write_session "OVERSEER_DONE"
OUTPUT=$(run_hook '{"description":"PM-Admin: requirements quality review"}')
assert_allow "9. pm_admin_at_overseer_done" "$OUTPUT"
cleanup

# --- Test 10: designer_at_pm_admin_done ---
write_session "PM_ADMIN_DONE"
OUTPUT=$(run_hook '{"description":"Designer: UI/UX quality review"}')
assert_allow "10. designer_at_pm_admin_done" "$OUTPUT"
cleanup

# --- Test 11: any_at_complete ---
write_session "COMPLETE"
OUTPUT=$(run_hook '{"description":"Writer: implement changes"}')
assert_allow "11. any_at_complete" "$OUTPUT"
cleanup

# --- Test 12: alt_phrasing_write_changeset ---
write_session "USER_CONFIRMED"
OUTPUT=$(run_hook '{"description":"Write change-set 1: foo"}')
assert_allow "12. alt_phrasing_write_changeset" "$OUTPUT"
cleanup

# --- Test 13: word_boundary_rewriter ---
# Note: /Writer\b/ in the hook intentionally matches "Rewriter" too (broad pattern
# to prevent bypass via alternative phrasing, per hook comments).
# At INIT state, Writer requires USER_CONFIRMED, so this is BLOCKED.
write_session "INIT"
OUTPUT=$(run_hook '{"description":"Rewriter: do something"}')
assert_block "13. word_boundary_rewriter" "$OUTPUT"
cleanup

# --- Test 14: rejection_recovery_writer ---
write_session "GUARDIAN_DONE"
OUTPUT=$(run_hook '{"description":"Writer: re-implement after rejection"}')
assert_allow "14. rejection_recovery_writer" "$OUTPUT"
cleanup

echo ""
echo "$PASSED/$TOTAL PASSED"
