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

# Path guard: only pull when reading bochi-data
if [ -n "$FILE_PATH" ] && ! echo "$FILE_PATH" | grep -q "bochi-data"; then
  exit 0
fi

# If no file_path extracted, skip (fail-open)
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

# Ensure data dir exists (self-healing, same as bochi-s3-pull.sh)
[ -d "$DATA_DIR" ] || mkdir -p "$DATA_DIR"

# AWS CLI must be available
command -v aws &>/dev/null || exit 0

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
  --size-only \
  --region ap-northeast-1 \
  --quiet 2>/dev/null || true
