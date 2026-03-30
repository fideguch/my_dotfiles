#!/bin/bash
# Periodic safety-net push (cron/launchd every 5 min)
# Only syncs if files changed since last successful push
set -euo pipefail
BUCKET="bochi-sync-fumito"
DATA_DIR="$HOME/.claude/bochi-data"
LOCKFILE="/tmp/bochi-s3-sync.lock"
MARKER="/tmp/bochi-last-safety-push"

[ -d "$DATA_DIR" ] || exit 0
command -v aws &>/dev/null || exit 0

# Safety: broken symlink check
if [ -L "$DATA_DIR" ] && [ ! -d "$DATA_DIR" ]; then exit 0; fi

# Skip if no files modified since last push
if [ -f "$MARKER" ]; then
  NEWER=$(find "$DATA_DIR" -newer "$MARKER" -type f ! -name ".DS_Store" ! -name "*.tmp" ! -name "*.lock" 2>/dev/null | head -1)
  [ -z "$NEWER" ] && exit 0
fi

# Stale lock cleanup (120s timeout)
if [ -d "$LOCKFILE.d" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCKFILE.d" 2>/dev/null || stat -c %Y "$LOCKFILE.d" 2>/dev/null || echo 0) ))
  [ "$LOCK_AGE" -gt 120 ] && rmdir "$LOCKFILE.d" 2>/dev/null || true
fi

# Cross-platform lock
if command -v flock &>/dev/null; then
  exec 200>"$LOCKFILE"
  flock -n 200 || exit 0
else
  if ! mkdir "$LOCKFILE.d" 2>/dev/null; then exit 0; fi
  trap 'rmdir "$LOCKFILE.d" 2>/dev/null' EXIT
fi

aws s3 sync "$DATA_DIR/" "s3://$BUCKET/bochi-data/" \
  --exclude ".DS_Store" --exclude "*.tmp" --exclude "*.lock" \
  --region ap-northeast-1 --quiet 2>/dev/null || true

touch "$MARKER"
