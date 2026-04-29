#!/bin/bash
# PreToolUse(Read) hook: pull latest bochi-data from S3 before reading
# Sync execution (not async) — ensures data is fresh before Read proceeds
# 5-second debounce to avoid redundant pulls within same response
set -euo pipefail

BUCKET="bochi-sync-fumito"
DATA_DIR="$HOME/.claude/bochi-data"
LOCKFILE="/tmp/bochi-s3-sync.lock"
DEBOUNCE_FILE="/tmp/bochi-s3-pull-last"
DEBOUNCE_SECONDS=5

# Read stdin JSON from Claude Code hook
INPUT_JSON=$(cat)

# Extract file_path (same pattern as bochi-s3-push.sh)
FILE_PATH=$(echo "$INPUT_JSON" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || true)

# Fallback: Grep tool uses "path" instead of "file_path"
if [ -z "$FILE_PATH" ]; then
  FILE_PATH=$(echo "$INPUT_JSON" | grep -o '"path":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || true)
fi

# Path guard: only pull when reading/grepping bochi-data
if [ -n "$FILE_PATH" ] && ! echo "$FILE_PATH" | grep -q "bochi-data"; then
  exit 0
fi

# If no file_path or path extracted, skip (fail-open)
[ -z "$FILE_PATH" ] && exit 0

# Debounce: skip if last pull was within 5 seconds
if [ -f "$DEBOUNCE_FILE" ]; then
  LAST=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo "0")
  NOW=$(date +%s)
  DIFF=$((NOW - LAST))
  if [ "$DIFF" -lt "$DEBOUNCE_SECONDS" ]; then
    exit 0
  fi
fi

# Safety: if symlink exists but is broken, do NOT create a real directory
if [ -L "$DATA_DIR" ] && [ ! -d "$DATA_DIR" ]; then
  echo "WARNING: bochi-data symlink is broken (target missing)" >&2
  exit 0
fi
[ -d "$DATA_DIR" ] || mkdir -p "$DATA_DIR"

# Pre-flight: warn on nested bochi-data (sync bug recurrence guard)
if [ -d "$DATA_DIR/bochi-data" ]; then
  echo "WARNING: nested bochi-data detected at $DATA_DIR/bochi-data — cleanup: rm -rf '$DATA_DIR/bochi-data'" >&2
fi

# AWS CLI must be available
command -v aws &>/dev/null || exit 0

# Stale lock cleanup (120s timeout)
if [ -d "$LOCKFILE.d" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCKFILE.d" 2>/dev/null || stat -c %Y "$LOCKFILE.d" 2>/dev/null || echo 0) ))
  [ "$LOCK_AGE" -gt 120 ] && rmdir "$LOCKFILE.d" 2>/dev/null || true
fi

# mkdir lock (macOS/Linux compatible)
if command -v flock &>/dev/null; then
  exec 200>"$LOCKFILE"
  flock -n 200 || exit 0
else
  if ! mkdir "$LOCKFILE.d" 2>/dev/null; then exit 0; fi
  trap 'rmdir "$LOCKFILE.d" 2>/dev/null' EXIT
fi

# Update debounce timestamp (before sync to prevent race conditions)
date +%s > "$DEBOUNCE_FILE"

# S3 sync (fail-open: exit 0 on error)
aws s3 sync "s3://$BUCKET/bochi-data/" "$DATA_DIR/" \
  --exclude ".DS_Store" \
  --exclude "*.tmp" \
  --exact-timestamps \
  --region ap-northeast-1 \
  --quiet 2>/dev/null || true

# Merge index.jsonl: union of local + S3 entries by id/path
LOCAL_INDEX="$DATA_DIR/index.jsonl"
if [ -f "$LOCAL_INDEX" ]; then
  REMOTE_INDEX="/tmp/bochi-index-remote-$$.jsonl"
  aws s3 cp "s3://$BUCKET/bochi-data/index.jsonl" "$REMOTE_INDEX" \
    --region ap-northeast-1 --quiet 2>/dev/null || true
  if [ -f "$REMOTE_INDEX" ] && [ -s "$REMOTE_INDEX" ]; then
    python3 -c "
import json
seen = {}
for p in ['$REMOTE_INDEX', '$LOCAL_INDEX']:
    try:
        for line in open(p):
            line = line.strip()
            if not line: continue
            entry = json.loads(line)
            key = entry.get('id') or entry.get('path') or entry.get('file', '')
            if key: seen[key] = entry
    except Exception: pass
with open('$LOCAL_INDEX', 'w') as f:
    for e in seen.values():
        f.write(json.dumps(e, ensure_ascii=False) + '\n')
" 2>/dev/null || true
    rm -f "$REMOTE_INDEX"
  fi
fi
