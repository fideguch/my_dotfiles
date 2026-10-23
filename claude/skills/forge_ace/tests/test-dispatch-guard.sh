#!/usr/bin/env bash
set -euo pipefail

# test-dispatch-guard.sh — Tests for forge_ace Dispatch Guard Hook
# Verifies agent dispatch sequencing enforcement via session state.

HOOK_PATH="/Users/fumito_ideguchi/my_dotfiles/claude/scripts/hooks/forge-ace-dispatch-guard.js"
# Never touch a live run: everything lives in one temp folder; the hook reads FORGE_ACE_SESSION_FILE.
WORK="$(mktemp -d /tmp/forge-ace-test.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
SESSION_FILE="$WORK/session.json"
export FORGE_ACE_SESSION_FILE="$SESSION_FILE"
unset FORGE_ACE_STALE_HOURS
EXPECTED=22
PASSED=0
FAILED=0

if ! grep -q "process.env.FORGE_ACE_SESSION_FILE" "$HOOK_PATH"; then
  echo "ABORT: $HOOK_PATH ignores FORGE_ACE_SESSION_FILE"
  exit 1
fi

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
  # The hook reads the Claude Code payload ({tool_name, tool_input}) from stdin (not a TOOL_INPUT env var).
  printf '{"tool_name":"Agent","tool_input":%s}' "$tool_input" | node "$HOOK_PATH" 2>/dev/null || true
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

# --- Test 15: stale run (no update for 30h) no longer gates Agent calls ---
write_session "INIT"
python3 -c "import os,sys,time; t=time.time()-30*3600; os.utime(sys.argv[1],(t,t))" "$SESSION_FILE"
python3 - "$SESSION_FILE" <<'PYEOF'
import json, sys
from datetime import datetime, timedelta, timezone
p = sys.argv[1]; d = json.load(open(p))
d["created"] = (datetime.now(timezone.utc) - timedelta(hours=30)).strftime("%Y-%m-%dT%H:%M:%SZ")
json.dump(d, open(p, "w"))
PYEOF
python3 -c "import os,sys,time; t=time.time()-30*3600; os.utime(sys.argv[1],(t,t))" "$SESSION_FILE"
OUTPUT=$(run_hook '{"description":"Designer: unrelated project"}')
assert_allow "15. stale_run_does_not_gate" "$OUTPUT"
cleanup

# --- Test 16: a block explains how to clear an abandoned run ---
write_session "INIT"
OUTPUT=$(run_hook '{"description":"Guardian: verify"}')
assert_pass_contains() { if echo "$2" | grep -q "$3"; then echo "PASS: $1"; PASSED=$((PASSED + 1)); else echo "FAIL: $1"; FAILED=$((FAILED + 1)); fi; }
assert_pass_contains "16. block_reason_tells_how_to_clear" "$OUTPUT" "forge-ace-session.json"
cleanup

age_session() { python3 -c "import os,sys,time; t=time.time()-float(sys.argv[2])*3600; os.utime(sys.argv[1],(t,t))" "$SESSION_FILE" "$1"; }

# --- Test 17: `updated` just now keeps an old-looking run gating ---
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"2020-01-01T00:00:00Z","updated":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","state":"INIT","agents":{}}
SESS
age_session 30
OUTPUT=$(run_hook '{"description":"Guardian: verify"}')
assert_block "17. recent_updated_still_gates" "$OUTPUT"
cleanup

# --- Test 18: FORGE_ACE_STALE_HOURS=1 → a run idle for 2h no longer gates ---
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"2020-01-01T00:00:00Z","state":"INIT","agents":{}}
SESS
age_session 2
OUTPUT=$(FORGE_ACE_STALE_HOURS=1 run_hook '{"description":"Guardian: verify"}')
assert_allow "18. stale_hours_override" "$OUTPUT"
cleanup

# --- Test 19: broken JSON → allow (fail-open) ---
printf '{"state":"IN' > "$SESSION_FILE"
OUTPUT=$(run_hook '{"description":"Guardian: verify"}')
assert_allow "19. broken_json_allows" "$OUTPUT"
cleanup

# --- Test 20: non-object JSON → allow (fail-open) ---
printf '[]' > "$SESSION_FILE"
OUTPUT=$(run_hook '{"description":"Guardian: verify"}')
assert_allow "20. non_object_json_allows" "$OUTPUT"
cleanup

# --- Test 21: the block points at the run folder and asks for the user's confirmation ---
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","state":"INIT","run_dir":"/tmp/some-run-folder","agents":{}}
SESS
OUTPUT=$(run_hook '{"description":"Guardian: verify"}')
assert_pass_contains "21. block_points_at_run_dir_and_user" "$OUTPUT" "/tmp/some-run-folder/NEXT.md"
cleanup

# --- Test 22: a payload that arrives late on stdin is still read (a busy machine) ---
write_session "INIT"
OUTPUT=$( (sleep 0.5; printf '{"tool_name":"Agent","tool_input":{"description":"Guardian: verify"}}') | node "$HOOK_PATH" 2>/dev/null || true)
assert_block "22. late_stdin_still_gates" "$OUTPUT"
cleanup

TOTAL=$((PASSED + FAILED))
echo ""
echo "$PASSED/$TOTAL PASSED (expected $EXPECTED)"
[ "$FAILED" -eq 0 ] && [ "$TOTAL" -eq "$EXPECTED" ]
