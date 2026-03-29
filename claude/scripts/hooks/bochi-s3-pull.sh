#!/bin/bash
# SessionStart hook: pull latest bochi-data from S3
set -euo pipefail
BUCKET="bochi-sync-fumito"
DATA_DIR="$HOME/.claude/bochi-data"
LOCKFILE="/tmp/bochi-s3-sync.lock"

command -v aws &>/dev/null || exit 0
[ -d "$DATA_DIR" ] || mkdir -p "$DATA_DIR"

# Cross-platform lock: flock on Linux, mkdir on macOS
if command -v flock &>/dev/null; then
  exec 200>"$LOCKFILE"
  flock -n 200 || exit 0
else
  if ! mkdir "$LOCKFILE.d" 2>/dev/null; then exit 0; fi
  trap 'rmdir "$LOCKFILE.d" 2>/dev/null' EXIT
fi

if aws s3 ls "s3://$BUCKET/" --region ap-northeast-1 &>/dev/null 2>&1; then
  aws s3 sync "s3://$BUCKET/bochi-data/" "$DATA_DIR/" \
    --exclude ".DS_Store" \
    --exclude "*.tmp" \
    --size-only \
    --region ap-northeast-1 \
    --quiet
fi
