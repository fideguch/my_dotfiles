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

aws s3 sync "$DATA_DIR/" "s3://$BUCKET/bochi-data/" \
  --exclude ".DS_Store" \
  --exclude "*.tmp" \
  --exclude "*.lock" \
  --exclude "bochi-data/" \
  --exclude "topics/*" \
  --exclude "newspaper/*" \
  --exclude "conversations/*" \
  --exclude "reflections/*" \
  --exclude "seen.jsonl" \
  --region ap-northeast-1 \
  --quiet
