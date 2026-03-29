#!/bin/bash
# PostToolUse hook: bochi-data write/edit -> push to S3
# Runs async to avoid blocking Discord/CLI responses
set -euo pipefail
BUCKET="bochi-sync-fumito"
DATA_DIR="$HOME/.claude/bochi-data"
LOCKFILE="/tmp/bochi-s3-sync.lock"

[ -d "$DATA_DIR" ] || exit 0
command -v aws &>/dev/null || exit 0

# Read stdin JSON from Claude Code hook
INPUT_JSON=$(cat)

# Path guard: only sync when bochi-data was modified
FILE_PATH=$(echo "$INPUT_JSON" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || true)
if [ -n "$FILE_PATH" ] && ! echo "$FILE_PATH" | grep -q "bochi-data"; then
  exit 0
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
  --size-only \
  --region ap-northeast-1 \
  --quiet
