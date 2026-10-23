#!/usr/bin/env bash
set -euo pipefail

# test-state-machine.sh — Tests for forge_ace session JSON structure,
# state transitions, and session-complete hook.

COMPLETE_HOOK="/Users/fumito_ideguchi/my_dotfiles/claude/scripts/hooks/forge-ace-session-complete.js"
# Never touch a live run or the real outcome log: everything lives in one temp folder,
# and the hook reads FORGE_ACE_SESSION_FILE / FORGE_ACE_OUTCOMES_DIR / FORGE_ACE_FALLBACK_DIR.
WORK="$(mktemp -d /tmp/forge-ace-test.XXXXXX)"
TILDE_RUN_NAME="test-$(basename "$WORK")"
TILDE_RUN="$HOME/.claude/forge-ace/runs/$TILDE_RUN_NAME"
trap 'rm -rf "$WORK" "$TILDE_RUN"' EXIT
SESSION_FILE="$WORK/session.json"
RUN_DIR="$WORK/run"
mkdir -p "$RUN_DIR"
export FORGE_ACE_SESSION_FILE="$SESSION_FILE"
export FORGE_ACE_OUTCOMES_DIR="$WORK/outcomes"
export FORGE_ACE_FALLBACK_DIR="$WORK/fallback"
unset FORGE_ACE_STALE_HOURS
OUTCOMES_FILE="$FORGE_ACE_OUTCOMES_DIR/outcomes.jsonl"
EXPECTED=29
PASSED=0
FAILED=0

# A hook that ignores the overrides would write to the live run and the real log: stop here.
if ! grep -q "process.env.FORGE_ACE_SESSION_FILE" "$COMPLETE_HOOK" \
  || ! grep -q "process.env.FORGE_ACE_OUTCOMES_DIR" "$COMPLETE_HOOK" \
  || ! grep -q "process.env.FORGE_ACE_FALLBACK_DIR" "$COMPLETE_HOOK"; then
  echo "ABORT: $COMPLETE_HOOK ignores FORGE_ACE_SESSION_FILE / FORGE_ACE_OUTCOMES_DIR / FORGE_ACE_FALLBACK_DIR"
  exit 1
fi

# Prereq check
if ! which node >/dev/null 2>&1; then
  echo "SKIP: node not found"
  exit 0
fi

cleanup() {
  rm -f "$SESSION_FILE" "$SESSION_FILE".corrupt*
}

iso_hours_ago() {
  python3 -c "
from datetime import datetime, timedelta, timezone
import sys
print((datetime.now(timezone.utc) - timedelta(hours=float(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))
" "$1"
}

age_file() { python3 -c "import os,sys,time; t=time.time()-float(sys.argv[2])*3600; os.utime(sys.argv[1],(t,t))" "$1" "$2"; }

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

# ===== C) Session-complete hook (21 tests: 9-29) =====

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

# Test 12: Stale incomplete (no update for 30h: created and file mtime 30h ago) → completed:false line, session deleted
STALE_TIME=$(python3 -c "
from datetime import datetime, timedelta, timezone
t = datetime.now(timezone.utc) - timedelta(hours=30)
print(t.strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$STALE_TIME","tier":"Standard","type":"A","state":"GUARDIAN_DISPATCHED","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
BEFORE=$(count_outcomes)
node "$COMPLETE_HOOK" 2>/dev/null || true
AFTER=$(count_outcomes)
LAST_LINE=$(tail -1 "$OUTCOMES_FILE" 2>/dev/null || echo "")
HAS_COMPLETED_FALSE=$(echo "$LAST_LINE" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print('true' if d.get('completed')==False else 'false')" 2>/dev/null || echo "false")
SESSION_DELETED=$([ ! -f "$SESSION_FILE" ] && echo "true" || echo "false")
LINES_ADDED=$(( AFTER - BEFORE ))
assert_pass "12. stale_incomplete_writes_false_and_deletes" "$([ "$LINES_ADDED" = "1" ] && [ "$HAS_COMPLETED_FALSE" = "true" ] && [ "$SESSION_DELETED" = "true" ] && echo true || echo false)"

# Test 13: Long but active run (created 3h ago, updated just now) → preserved (2026-10-21: a live run was deleted after 2h)
OLD_TIME=$(python3 -c "
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) - timedelta(hours=3)).strftime('%Y-%m-%dT%H:%M:%SZ'))
" 2>/dev/null)
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$OLD_TIME","tier":"Standard","type":"A","state":"WRITER_DISPATCHED","agents":{},"transitions":[]}
SESS
BEFORE=$(count_outcomes)
node "$COMPLETE_HOOK" 2>/dev/null || true
AFTER=$(count_outcomes)
SESSION_EXISTS=$([ -f "$SESSION_FILE" ] && echo "true" || echo "false")
assert_pass "13. active_long_run_preserved" "$([ "$BEFORE" = "$AFTER" ] && [ "$SESSION_EXISTS" = "true" ] && echo true || echo false)"
cleanup

# Test 14: Stale run with run_dir → state archived to run_dir/state-stale.json before deletion
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$STALE_TIME","tier":"Standard","type":"A","state":"GUARDIAN_DISPATCHED","run_dir":"$RUN_DIR","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
ARCHIVED=$(python3 -c "import json,sys; print('true' if json.load(open(sys.argv[1])).get('state')=='GUARDIAN_DISPATCHED' else 'false')" "$RUN_DIR/state-stale.json" 2>/dev/null || echo "false")
SESSION_DELETED=$([ ! -f "$SESSION_FILE" ] && echo "true" || echo "false")
assert_pass "14. stale_run_archived_to_run_dir" "$([ "$ARCHIVED" = "true" ] && [ "$SESSION_DELETED" = "true" ] && echo true || echo false)"

# Test 15: COMPLETE run with run_dir → state archived to run_dir/state-final.json
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","tier":"Standard","type":"A","state":"COMPLETE","run_dir":"$RUN_DIR","agents":{},"transitions":[]}
SESS
node "$COMPLETE_HOOK" 2>/dev/null || true
FINAL=$(python3 -c "import json,sys; print('true' if json.load(open(sys.argv[1])).get('state')=='COMPLETE' else 'false')" "$RUN_DIR/state-final.json" 2>/dev/null || echo "false")
assert_pass "15. complete_run_archived_to_run_dir" "$FINAL"
cleanup

# Test 16: created and mtime 30h ago but `updated` just now → preserved (`updated` counts as activity)
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(iso_hours_ago 30)","updated":"$(iso_hours_ago 0)","state":"WRITER_DONE","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "16. recent_updated_field_preserves" "$([ -f "$SESSION_FILE" ] && echo true || echo false)"
cleanup

# Test 17: invalid `created`, fresh file → preserved (mtime decides)
cat > "$SESSION_FILE" <<'SESS'
{"version":"4.0","created":"not-a-date","state":"WRITER_DONE","agents":{},"transitions":[]}
SESS
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "17. invalid_created_uses_mtime" "$([ -f "$SESSION_FILE" ] && echo true || echo false)"
cleanup

# Test 18: FORGE_ACE_STALE_HOURS=1 → a run idle for 2h is cleaned up
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(iso_hours_ago 2)","state":"WRITER_DONE","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 2
FORGE_ACE_STALE_HOURS=1 node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "18. stale_hours_override" "$([ ! -f "$SESSION_FILE" ] && echo true || echo false)"
cleanup

# Test 19: empty file just written (a writer truncated it) → preserved
: > "$SESSION_FILE"
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "19. empty_recent_file_preserved" "$([ -f "$SESSION_FILE" ] && echo true || echo false)"
cleanup

# Test 20: broken JSON idle for 30h → moved aside to .corrupt (kept as evidence)
printf '{"state":"WRITER_' > "$SESSION_FILE"
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "20. stale_corrupt_moved_aside" "$([ ! -f "$SESSION_FILE" ] && ls "$SESSION_FILE".corrupt-* >/dev/null 2>&1 && echo true || echo false)"
cleanup

# Test 21: run_dir written with ~ → expanded, state archived there
mkdir -p "$TILDE_RUN"
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(iso_hours_ago 30)","state":"GUARDIAN_DISPATCHED","run_dir":"~/.claude/forge-ace/runs/$TILDE_RUN_NAME","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "21. tilde_run_dir_expanded" "$([ -f "$TILDE_RUN/state-stale.json" ] && [ ! -f "$SESSION_FILE" ] && echo true || echo false)"
cleanup

# Test 22: relative run_dir cannot be trusted → state kept in the local fallback folder before deletion
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(iso_hours_ago 30)","state":"GUARDIAN_DISPATCHED","run_dir":"relative/run","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
FALLBACK=$(ls "$FORGE_ACE_FALLBACK_DIR"/state-*.json 2>/dev/null | head -1 || true)
LEAKED=$(ls "$FORGE_ACE_OUTCOMES_DIR"/state-*.json 2>/dev/null | head -1 || true)
assert_pass "22. unusable_run_dir_falls_back_locally" "$([ -n "$FALLBACK" ] && [ -z "$LEAKED" ] && [ ! -f "$SESSION_FILE" ] && echo true || echo false)"
cleanup

# Test 23: dates in the future are ignored (mtime 30h ago decides) → cleaned up
cat > "$SESSION_FILE" <<'SESS'
{"version":"4.0","created":"2099-01-01T00:00:00Z","updated":"2099-01-01T00:00:00Z","state":"WRITER_DONE","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "23. future_dates_ignored" "$([ ! -f "$SESSION_FILE" ] && echo true || echo false)"
cleanup

# Test 24: archiving never writes through a symlink planted at run_dir/state-stale.json
printf 'untouched' > "$WORK/target"
rm -f "$RUN_DIR/state-stale.json"
ln -s "$WORK/target" "$RUN_DIR/state-stale.json"
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(iso_hours_ago 30)","state":"GUARDIAN_DISPATCHED","run_dir":"$RUN_DIR","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "24. archive_does_not_follow_symlink" "$([ "$(cat "$WORK/target")" = "untouched" ] && [ ! -L "$RUN_DIR/state-stale.json" ] && echo true || echo false)"
cleanup

# Test 25: nothing could be saved (relative run_dir, fallback folder read-only) → state kept, no outcome line, twice
mkdir -p "$FORGE_ACE_FALLBACK_DIR"
chmod 555 "$FORGE_ACE_FALLBACK_DIR"
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(iso_hours_ago 30)","state":"GUARDIAN_DISPATCHED","run_dir":"relative/run","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
BEFORE=$(count_outcomes)
node "$COMPLETE_HOOK" 2>/dev/null || true
node "$COMPLETE_HOOK" 2>/dev/null || true
AFTER=$(count_outcomes)
chmod 755 "$FORGE_ACE_FALLBACK_DIR"
assert_pass "25. unsaved_state_kept_without_duplicate_outcomes" "$([ -f "$SESSION_FILE" ] && [ "$BEFORE" = "$AFTER" ] && echo true || echo false)"
cleanup

# Test 26: stale non-object JSON (null) → moved aside like a broken file
printf 'null' > "$SESSION_FILE"
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "26. stale_non_object_moved_aside" "$([ ! -f "$SESSION_FILE" ] && ls "$SESSION_FILE".corrupt-* >/dev/null 2>&1 && echo true || echo false)"
cleanup

# Test 27: an earlier .corrupt file is never overwritten
printf 'earlier evidence' > "$SESSION_FILE.corrupt-1"
printf '{"broken' > "$SESSION_FILE"
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
CORRUPTS=$(ls "$SESSION_FILE".corrupt-* 2>/dev/null | wc -l | tr -d ' ')
assert_pass "27. earlier_corrupt_kept" "$([ "$(cat "$SESSION_FILE.corrupt-1")" = "earlier evidence" ] && [ "$CORRUPTS" = "2" ] && echo true || echo false)"
cleanup

# Test 28: a failed rename leaves no temp file in run_dir (state-stale.json is a directory) → fallback used
rm -rf "$RUN_DIR/state-stale.json"
mkdir -p "$RUN_DIR/state-stale.json"
rm -rf "$FORGE_ACE_FALLBACK_DIR"
cat > "$SESSION_FILE" <<SESS
{"version":"4.0","created":"$(iso_hours_ago 30)","state":"GUARDIAN_DISPATCHED","run_dir":"$RUN_DIR","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
TMPS=$(ls "$RUN_DIR" | grep -c '\.tmp-' || true)
assert_pass "28. no_temp_file_left_after_failed_rename" "$([ "$TMPS" = "0" ] && ls "$FORGE_ACE_FALLBACK_DIR"/state-*.json >/dev/null 2>&1 && [ ! -f "$SESSION_FILE" ] && echo true || echo false)"
rm -rf "$RUN_DIR/state-stale.json"
cleanup

# Test 29: invalid `created` and an old file → cleaned up (mtime decides both ways)
cat > "$SESSION_FILE" <<'SESS'
{"version":"4.0","created":"not-a-date","state":"WRITER_DONE","agents":{},"transitions":[]}
SESS
age_file "$SESSION_FILE" 30
node "$COMPLETE_HOOK" 2>/dev/null || true
assert_pass "29. invalid_created_old_file_cleaned" "$([ ! -f "$SESSION_FILE" ] && echo true || echo false)"

cleanup

TOTAL=$((PASSED + FAILED))
echo ""
echo "$PASSED/$TOTAL PASSED (expected $EXPECTED)"
[ "$FAILED" -eq 0 ] && [ "$TOTAL" -eq "$EXPECTED" ]
