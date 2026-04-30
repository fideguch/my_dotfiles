#!/bin/bash
# PostToolUse hook: bochi-data write/edit -> push to S3
# Runs async to avoid blocking Discord/CLI responses
set -euo pipefail
BUCKET="bochi-sync-fumito"
DATA_DIR="$HOME/.claude/bochi-data"
LOCKFILE="/tmp/bochi-s3-sync.lock"

# Safety: if symlink exists but is broken, warn and skip (prevent data split)
if [ -L "$DATA_DIR" ] && [ ! -d "$DATA_DIR" ]; then
  echo "WARNING: bochi-data symlink is broken (target missing)" >&2
  exit 0
fi
[ -d "$DATA_DIR" ] || exit 0
command -v aws &>/dev/null || exit 0

# Pre-flight: warn on nested bochi-data (sync bug recurrence guard)
if [ -d "$DATA_DIR/bochi-data" ]; then
  echo "WARNING: nested bochi-data detected at $DATA_DIR/bochi-data — cleanup: rm -rf '$DATA_DIR/bochi-data'" >&2
fi

# Read stdin JSON from Claude Code hook
INPUT_JSON=$(cat)

# Path guard: only sync when bochi-data was modified
FILE_PATH=$(echo "$INPUT_JSON" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || true)
if [ -n "$FILE_PATH" ] && ! echo "$FILE_PATH" | grep -q "bochi-data"; then
  exit 0
fi

# Stale lock cleanup (120s timeout)
if [ -d "$LOCKFILE.d" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCKFILE.d" 2>/dev/null || stat -c %Y "$LOCKFILE.d" 2>/dev/null || echo 0) ))
  [ "$LOCK_AGE" -gt 120 ] && rmdir "$LOCKFILE.d" 2>/dev/null || true
fi

# Cross-platform lock: flock on Linux, mkdir on macOS
if command -v flock &>/dev/null; then
  exec 200>"$LOCKFILE"
  flock -n 200 || exit 0
else
  if ! mkdir "$LOCKFILE.d" 2>/dev/null; then exit 0; fi
  trap 'rmdir "$LOCKFILE.d" 2>/dev/null' EXIT
fi

# Write Ownership: Mac pushes only memos/index/context-seeds,
# Lightsail pushes only topics/newspaper/conversations/reflections/seen
EXCLUDE_COMMON=(--exclude ".DS_Store" --exclude "*.tmp" --exclude "*.lock" --exclude "bochi-data/*")

if [ "$(uname)" = "Darwin" ]; then
  # Mac CLI: exclude Lightsail-owned directories
  EXCLUDE_OWNERSHIP=(--exclude "topics/*" --exclude "newspaper/*" --exclude "conversations/*" --exclude "reflections/*" --exclude "seen.jsonl" --exclude "sources/*" --exclude "stats/*" --exclude "user-profile.yaml" --exclude "cache/*")
else
  # Lightsail: exclude Mac-owned directories
  EXCLUDE_OWNERSHIP=(--exclude "context-seeds/*")
fi

# Logging setup (additive — preserves async hook contract: never fail caller)
LOG_FILE="$HOME/.claude/logs/bochi-s3-push.log"
LOG_MAX_SIZE=$((10 * 1024 * 1024))  # 10MB
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Rotate if oversize (Mac stat -f %z, Linux stat -c %s)
if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(stat -f %z "$LOG_FILE" 2>/dev/null || stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$LOG_SIZE" -gt "$LOG_MAX_SIZE" ]; then
    mv "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
    gzip -f "$LOG_FILE.1" 2>/dev/null || true
  fi
fi

# Capture sync result without propagating failure (async contract)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SYNC_STDERR=$(mktemp -t bochi-sync.XXXXXX)
set +e
aws s3 sync "$DATA_DIR/" "s3://$BUCKET/bochi-data/" \
  "${EXCLUDE_COMMON[@]}" \
  "${EXCLUDE_OWNERSHIP[@]}" \
  --region ap-northeast-1 \
  --quiet 2>"$SYNC_STDERR"
SYNC_EXIT=$?
set -e

if [ "$SYNC_EXIT" -ne 0 ]; then
  STDERR_SNIPPET=$(head -c 2000 "$SYNC_STDERR" 2>/dev/null | tr '\n' ' ' | tr -d '\r' || echo "")
  printf '%s exit=%d stderr=%s\n' "$TIMESTAMP" "$SYNC_EXIT" "$STDERR_SNIPPET" >> "$LOG_FILE"

  # Threshold: 3+ failures in last 60 minutes → notify (cooldown 1h)
  ONE_HOUR_AGO=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  if [ -n "$ONE_HOUR_AGO" ]; then
    RECENT_FAILS=$(awk -v cutoff="$ONE_HOUR_AGO" '$1 >= cutoff' "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
  else
    RECENT_FAILS=0
  fi
  NOTIFY_MARKER="/tmp/bochi-s3-notify-last"
  NOTIFY_AGE=999999
  if [ -f "$NOTIFY_MARKER" ]; then
    NOTIFY_AGE=$(( $(date +%s) - $(stat -f %m "$NOTIFY_MARKER" 2>/dev/null || stat -c %Y "$NOTIFY_MARKER" 2>/dev/null || echo 0) ))
  fi
  if [ "$RECENT_FAILS" -ge 3 ] && [ "$NOTIFY_AGE" -gt 3600 ]; then
    osascript -e "display notification \"bochi S3 sync failed ${RECENT_FAILS}x in last hour. Check ~/.claude/logs/bochi-s3-push.log\" with title \"bochi S3 Sync Alert\"" 2>/dev/null || true
    touch "$NOTIFY_MARKER"
  fi
fi

rm -f "$SYNC_STDERR" 2>/dev/null || true
exit 0  # async hook contract: never block caller
