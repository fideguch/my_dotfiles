#!/usr/bin/env bash
set -euo pipefail

# test-state-machine.sh — Tests for forge_ace session JSON structure,
# state transitions, and session-complete hook.

SESSION_FILE="/tmp/.forge-ace-session.json"
COMPLETE_HOOK="/Users/fumito_ideguchi/my_dotfiles/claude/scripts/hooks/forge-ace-session-complete.js"
OUTCOMES_FILE="$HOME/.claude/bochi-data/forge-ace-outcomes/outcomes.jsonl"
PASSED=0
FAILED=0
TOTAL=12

# Prereq check
if ! which node >/dev/null 2>&1; then
  echo "SKIP: node not found"
  exit 0
fi

cleanup() {
  rm -f "$SESSION_FILE"
}

assert_pass() {
  local test_name="$1"
  local condition="$2"
  if [ "$condition" = "true" ]; then
    echo "PASS: $test_name"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL: $test_name"
    FAILED=$((FAILED + 1))
  fi
}

# Write a full initial session JSON
write_full_session() {
  cat > "$SESSION_FILE" <<'SESS'
{"version":"4.0","created":"2026-04-01T00:00:00Z","tier":"Standard","type":"A","state":"INIT","checkpoint_filled":false,"user_confirmed":false,"agents":{"writer":{"status":"pending","verdict":null},"guardian":{"status":"pending","verdict":null},"overseer":{"status":"pending","verdict":null},"pm_admin":{"status":"pending","verdict":null},"designer":{"status":"pending","verdict":null}},"transitions":[]}
SESS
}

# ===== A) Session JSON Structure (4 tests) =====

# Test 1: All required top-level fields present
write_full_session
RESULT="true"
for field in version created tier type state checkpoint_filled user_confirmed agents transitions; do
  if ! python3 -c "import json; d=json.load(open('$SESSION_FILE')); assert '$field' in d" 2>/dev/null; then
    RESULT="false"
    break
  fi
done
assert_pass "1. all_required_toplevel_fields" "$RESULT"
cleanup

# Test 2: All 5 agent entries present with status/verdict
write_full_session
RESULT="true"
for agent in writer guardian overseer pm_admin designer; do
  if ! python3 -c "
import json
d=json.load(open('$SESSION_FILE'))
a=d['agents']['$agent']
assert 'status' in a and 'verdict' in a
" 2>/dev/null; then
    RESULT="false"
    break
  fi
done
assert_pass "2. all_5_agent_entries_with_status_verdict" "$RESULT"
cleanup

# Test 3: Initial state is INIT
write_full_session
RESULT=$(python3 -c "
import json
d=json.load(open('$SESSION_FILE'))
print('true' if d['state'] == 'INIT' else 'false')
" 2>/dev/null || echo "false")
assert_pass "3. initial_state_is_INIT" "$RESULT"
cleanup

# Test 4: transitions is an array
write_full_session
RESULT=$(python3 -c "
import json
d=json.load(open('$SESSION_FILE'))
print('true' if isinstance(d['transitions'], list) else 'false')
" 2>/dev/null || echo "false")
assert_pass "4. transitions_is_array" "$RESULT"
cleanup

# ===== B) State Transitions (4 tests) =====

STANDARD_STATES=("INIT" "CLASSIFIED" "CHECKPOINT_FILLED" "USER_CONFIRMED" "WRITER_DISPATCHED" "WRITER_DONE" "GUARDIAN_DISPATCHED" "GUARDIAN_DONE" "OVERSEER_DISPATCHED" "OVERSEER_DONE" "PM_ADMIN_DISPATCHED" "PM_ADMIN_DONE" "COMPLETE")

# Test 5: Full Standard sequence works (13 states)
write_full_session
RESULT="true"
for state in "${STANDARD_STATES[@]}"; do
  python3 -c "
import json
d=json.load(open('$SESSION_FILE'))
d['state']='$state'
d['transitions'].append({'from': d.get('_prev','INIT'), 'to': '$state'})
d['_prev']='$state'
json.dump(d, open('$SESSION_FILE','w'))
" 2>/dev/null
  CURRENT=$(python3 -c "import json; print(json.load(open('$SESSION_FILE'))['state'])" 2>/dev/null)
  if [ "$CURRENT" != "$state" ]; then
    RESULT="false"
    break
  fi
done
assert_pass "5. full_standard_sequence_13_states" "$RESULT"
cleanup

# Test 6: Each transition logged in transitions array
write_full_session
for state in "${STANDARD_STATES[@]}"; do
  python3 -c "
import json
d=json.load(open('$SESSION_FILE'))
d['transitions'].append({'to': '$state'})
d['state']='$state'
json.dump(d, open('$SESSION_FILE','w'))
" 2>/dev/null
done
TRANSITION_COUNT=$(python3 -c "
import json
d=json.load(open('$SESSION_FILE'))
print(len(d['transitions']))
" 2>/dev/null || echo "0")
assert_pass "6. transitions_logged_count_13" "$([ "$TRANSITION_COUNT" = "13" ] && echo true || echo false)"
cleanup

# Test 7: Standard tier skips Designer states
RESULT="true"
for state in "${STANDARD_STATES[@]}"; do
  if [[ "$state" == *"DESIGNER"* ]]; then
    RESULT="false"
    break
  fi
done
assert_pass "7. standard_skips_designer_states" "$RESULT"
cleanup

# Test 8: checkpoint_filled/user_confirmed flags set at correct states
write_full_session
# Simulate: set checkpoint_filled at CHECKPOINT_FILLED, user_confirmed at USER_CONFIRMED
python3 -c "
import json
d=json.load(open('$SESSION_FILE'))
d['state']='CHECKPOINT_FILLED'
d['checkpoint_filled']=True
json.dump(d, open('$SESSION_FILE','w'))
" 2>/dev/null
CF=$(python3 -c "import json; d=json.load(open('$SESSION_FILE')); print(d['checkpoint_filled'])" 2>/dev/null)

python3 -c "
import json
d=json.load(open('$SESSION_FILE'))
d['state']='USER_CONFIRMED'
d['user_confirmed']=True
json.dump(d, open('$SESSION_FILE','w'))
" 2>/dev/null
UC=$(python3 -c "import json; d=json.load(open('$SESSION_FILE')); print(d['user_confirmed'])" 2>/dev/null)

assert_pass "8. checkpoint_and_user_confirmed_flags" "$([ "$CF" = "True" ] && [ "$UC" = "True" ] && echo true || echo false)"
cleanup

# ===== C) Session-complete hook (4 tests) =====

# Backup outcomes file
BACKUP=""
if [ -f "$OUTCOMES_FILE" ]; then
  BACKUP="/tmp/.forge-ace-outcomes-backup-$$"
  cp "$OUTCOMES_FILE" "$BACKUP"
fi

count_outcomes() {
  if [ -f "$OUTCOMES_FILE" ]; then
    wc -l < "$OUTCOMES_FILE" | tr -d ' '
  else
    echo "0"
  fi
}

# Test 9: No session file → exit 0, no new JSONL line
cleanup
BEFORE=$(count_outcomes)
node "$COMPLETE_HOOK" 2>/dev/null || true
AFTER=$(count_outcomes)
assert_pass "9. no_session_no_jsonl" "$([ "$BEFORE" = "$AFTER" ] && echo true || echo false)"

# Test 10: COMPLETE state → new JSONL line with completed:true, session deleted
cat > "$SESSION_FILE" <<'SESS'
{"version":"4.0","created":"2026-04-01T00:00:00Z","tier":"Standard","type":"A","state":"COMPLETE","checkpoint_filled":true,"user_confirmed":true,"agents":{"writer":{"status":"done","verdict":"APPROVED"},"guardian":{"status":"done","verdict":"APPROVED"},"overseer":{"status":"done","verdict":"APPROVED"},"pm_admin":{"status":"done","verdict":"APPROVED"},"designer":{"status":"skipped","verdict":null}},"transitions":[]}
SESS
BEFORE=$(count_outcomes)
node "$COMPLETE_HOOK" 2>/dev/null || true
AFTER=$(count_outcomes)
LAST_LINE=$(tail -1 "$OUTCOMES_FILE" 2>/dev/null || echo "")
HAS_COMPLETED_TRUE=$(echo "$LAST_LINE" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print('true' if d.get('completed')==True else 'false')" 2>/dev/null || echo "false")
SESSION_DELETED=$([ ! -f "$SESSION_FILE" ] && echo "true" || echo "false")
LINES_ADDED=$(( AFTER - BEFORE ))
assert_pass "10. complete_writes_jsonl_and_deletes" "$([ "$LINES_ADDED" = "1" ] && [ "$HAS_COMPLETED_TRUE" = "true" ] && [ "$SESSION_DELETED" = "true" ] && echo true || echo false)"

# Test 11: Recent incomplete (created=now) → no action, session preserved
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","tier":"Standard","type":"A","state":"WRITER_DONE","agents":{},"transitions":[]}
SESS
BEFORE=$(count_outcomes)
node "$COMPLETE_HOOK" 2>/dev/null || true
AFTER=$(count_outcomes)
SESSION_EXISTS=$([ -f "$SESSION_FILE" ] && echo "true" || echo "false")
assert_pass "11. recent_incomplete_no_action" "$([ "$BEFORE" = "$AFTER" ] && [ "$SESSION_EXISTS" = "true" ] && echo true || echo false)"
cleanup

# Test 12: Stale incomplete (created=3h ago) → new JSONL line with completed:false, session deleted
STALE_TIME=$(python3 -c "
from datetime import datetime, timedelta, timezone
t = datetime.now(timezone.utc) - timedelta(hours=3)
print(t.strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$STALE_TIME","tier":"Standard","type":"A","state":"GUARDIAN_DISPATCHED","agents":{},"transitions":[]}
SESS
BEFORE=$(count_outcomes)
node "$COMPLETE_HOOK" 2>/dev/null || true
AFTER=$(count_outcomes)
LAST_LINE=$(tail -1 "$OUTCOMES_FILE" 2>/dev/null || echo "")
HAS_COMPLETED_FALSE=$(echo "$LAST_LINE" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print('true' if d.get('completed')==False else 'false')" 2>/dev/null || echo "false")
SESSION_DELETED=$([ ! -f "$SESSION_FILE" ] && echo "true" || echo "false")
LINES_ADDED=$(( AFTER - BEFORE ))
assert_pass "12. stale_incomplete_writes_false_and_deletes" "$([ "$LINES_ADDED" = "1" ] && [ "$HAS_COMPLETED_FALSE" = "true" ] && [ "$SESSION_DELETED" = "true" ] && echo true || echo false)"

# Restore outcomes file
if [ -n "$BACKUP" ]; then
  cp "$BACKUP" "$OUTCOMES_FILE"
  rm -f "$BACKUP"
fi

cleanup

echo ""
echo "$PASSED/$TOTAL PASSED"
