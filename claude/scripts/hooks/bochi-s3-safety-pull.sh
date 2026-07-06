#!/bin/bash
# Periodic safety-net pull (Lightsail cron every 5 min)
# Pulls from S3 + merges index.jsonl to prevent entry loss
set -euo pipefail
BUCKET="bochi-sync-fumito"
DATA_DIR="$HOME/.claude/bochi-data"
LOCKFILE="/tmp/bochi-s3-sync.lock"

# Safety: broken symlink check
if [ -L "$DATA_DIR" ] && [ ! -d "$DATA_DIR" ]; then exit 0; fi
[ -d "$DATA_DIR" ] || mkdir -p "$DATA_DIR"
command -v aws &>/dev/null || exit 0

# Pre-flight: warn on nested bochi-data (sync bug recurrence guard)
if [ -d "$DATA_DIR/bochi-data" ]; then
  echo "WARNING: nested bochi-data detected at $DATA_DIR/bochi-data — cleanup: rm -rf '$DATA_DIR/bochi-data'" >&2
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

# Pull from S3 (seen.jsonl excluded — union-merged below, v2.6)
aws s3 sync "s3://$BUCKET/bochi-data/" "$DATA_DIR/" \
  --exclude ".DS_Store" --exclude "*.tmp" --exclude "seen.jsonl" \
  --exact-timestamps \
  --region ap-northeast-1 --quiet 2>/dev/null || true

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

# v2.6: seen.jsonl co-owned (Mac bridge + Lightsail) — union-merge
LOCAL_SEEN="$DATA_DIR/seen.jsonl"
REMOTE_SEEN="/tmp/bochi-seen-remote-$$.jsonl"
aws s3 cp "s3://$BUCKET/bochi-data/seen.jsonl" "$REMOTE_SEEN" \
  --region ap-northeast-1 --quiet 2>/dev/null || true
if [ -f "$REMOTE_SEEN" ] && [ -s "$REMOTE_SEEN" ]; then
  python3 - "$LOCAL_SEEN" "$REMOTE_SEEN" <<'PYEOF' || true
import json, os, sys
local, remote = sys.argv[1], sys.argv[2]
keys, out = set(), []
def keyof(line):
    try:
        e = json.loads(line)
        return e.get('url') or e.get('id') or line
    except Exception:
        return line
for p in (local, remote):
    if not os.path.exists(p):
        continue
    try:
        for line in open(p):
            line = line.rstrip('\n')
            if not line.strip():
                continue
            k = keyof(line)
            if k not in keys:
                keys.add(k)
                out.append(line)
    except Exception:
        pass
with open(local, 'w') as f:
    f.write('\n'.join(out) + ('\n' if out else ''))
PYEOF
fi
rm -f "$REMOTE_SEEN" 2>/dev/null || true
