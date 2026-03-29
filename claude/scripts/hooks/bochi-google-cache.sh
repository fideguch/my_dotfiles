#!/bin/bash
# Google Calendar + Gmail cache generator
# Runs via launchd (hourly) or manually
# Pattern: bochi-s3-push.sh (lock, error handling, S3 sync)
set -euo pipefail

GOG="/opt/homebrew/bin/gog"
ACCOUNT="2000fumito@gmail.com"
BUCKET="bochi-sync-fumito"
CACHE_DIR="$HOME/.claude/bochi-data/cache"
META_FILE="$CACHE_DIR/meta.json"
DATA_DIR="$HOME/.claude/bochi-data"
LOCKFILE="/tmp/bochi-google-cache.lock"

# Prereqs: gog CLI must be installed (Mac only)
[ -x "$GOG" ] || exit 0

# Network check with timeout (handles sleep/wake)
if ! curl -sf --connect-timeout 5 --max-time 10 "https://www.google.com" -o /dev/null 2>/dev/null; then
  echo "$(date -Iseconds) WARN: no network connectivity, skipping cache update" >&2
  exit 0
fi

# mkdir lock (macOS compatible, same pattern as bochi-s3-push.sh)
if ! mkdir "$LOCKFILE" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCKFILE" 2>/dev/null' EXIT

# Ensure cache dir exists
mkdir -p "$CACHE_DIR"

CAL_EVENTS=0
GMAIL_MESSAGES=0
ERRORS=0

# --- Calendar ---
TO_DATE=$(date -v+3d +%Y-%m-%d)
CAL_JSON=$("$GOG" cal events --from today --to "$TO_DATE" --json -a "$ACCOUNT" 2>/dev/null || echo "[]")

if [ "$CAL_JSON" != "[]" ] && [ -n "$CAL_JSON" ]; then
  CAL_EVENTS=$(echo "$CAL_JSON" | python3 -c "
import sys, json
from datetime import datetime, timedelta

data = json.load(sys.stdin)
events = data if isinstance(data, list) else data.get('events', data.get('items', []))

# Group by date
by_date = {}
for ev in events:
    start = ev.get('start', {})
    dt_str = start.get('dateTime', start.get('date', ''))
    if not dt_str:
        continue
    date_key = dt_str[:10]
    if date_key not in by_date:
        by_date[date_key] = []
    # Extract time
    time_str = ''
    if 'T' in dt_str:
        time_str = dt_str[11:16]
    end = ev.get('end', {})
    end_str = end.get('dateTime', end.get('date', ''))
    end_time = ''
    if end_str and 'T' in end_str:
        end_time = end_str[11:16]
    summary = ev.get('summary', ev.get('title', 'No title'))
    by_date[date_key].append({
        'time': time_str,
        'end_time': end_time,
        'summary': summary
    })

# Format output
today = datetime.now()
days_ja = ['月', '火', '水', '木', '金', '土', '日']
lines = []
for i in range(3):
    d = today + timedelta(days=i)
    date_key = d.strftime('%Y-%m-%d')
    day_label = f'{d.month}/{d.day} ({days_ja[d.weekday()]})'
    lines.append(f'## {day_label}')
    day_events = by_date.get(date_key, [])
    if not day_events:
        lines.append('予定なし')
    else:
        for j, ev in enumerate(day_events[:5], 1):
            if ev['time'] and ev['end_time']:
                lines.append(f\"{j}. {ev['time']}-{ev['end_time']} — **{ev['summary']}**\")
            elif ev['time']:
                lines.append(f\"{j}. {ev['time']} — **{ev['summary']}**\")
            else:
                lines.append(f\"{j}. 終日 — **{ev['summary']}**\")
    lines.append('')

print(len(events))
print('---CONTENT---')
print('\n'.join(lines))
" 2>/dev/null || echo "0")

  if echo "$CAL_EVENTS" | grep -qF -- "---CONTENT---"; then
    CONTENT=$(echo "$CAL_EVENTS" | sed -n '/---CONTENT---/,$ p' | tail -n +2)
    CAL_EVENTS=$(echo "$CAL_EVENTS" | head -1)
    echo "$CONTENT" > "$CACHE_DIR/calendar.md"
  else
    CAL_EVENTS=0
    ERRORS=$((ERRORS + 1))
  fi
else
  # No events - write empty calendar
  TODAY_LABEL=$(date "+%-m/%-d")
  echo "## $TODAY_LABEL
予定なし
" > "$CACHE_DIR/calendar.md"
fi

# --- Gmail ---
GMAIL_JSON=$("$GOG" gmail search 'newer_than:3h -category:promotions -category:social -category:updates' --json -a "$ACCOUNT" 2>/dev/null || echo "[]")

if [ "$GMAIL_JSON" != "[]" ] && [ -n "$GMAIL_JSON" ]; then
  GMAIL_RESULT=$(echo "$GMAIL_JSON" | python3 -c "
import sys, json
from datetime import datetime

data = json.load(sys.stdin)
messages = data if isinstance(data, list) else data.get('messages', data.get('items', []))

lines = []
seen_senders = set()
count = 0
for msg in messages[:10]:
    sender = msg.get('from', msg.get('sender', 'Unknown'))
    # Clean sender name
    if '<' in sender:
        sender = sender.split('<')[0].strip().strip('\"')
    subject = msg.get('subject', msg.get('snippet', 'No subject'))
    date_str = msg.get('date', msg.get('internalDate', ''))
    time_label = ''
    if date_str:
        try:
            # Try parsing various date formats
            for fmt in ['%a, %d %b %Y %H:%M:%S %z', '%Y-%m-%dT%H:%M:%S%z']:
                try:
                    dt = datetime.strptime(date_str[:25].strip(), fmt)
                    time_label = f'({dt.strftime(\"%-H:%M\")})'
                    break
                except ValueError:
                    continue
        except Exception:
            pass
    count += 1
    lines.append(f'{count}. **{sender}** — {subject} {time_label}')

print(len(messages))
print('---CONTENT---')
print('\n'.join(lines) if lines else '新着メールなし')
" 2>/dev/null || echo "0")

  if echo "$GMAIL_RESULT" | grep -qF -- "---CONTENT---"; then
    CONTENT=$(echo "$GMAIL_RESULT" | sed -n '/---CONTENT---/,$ p' | tail -n +2)
    GMAIL_MESSAGES=$(echo "$GMAIL_RESULT" | head -1)
    echo "$CONTENT" > "$CACHE_DIR/gmail.md"
  else
    GMAIL_MESSAGES=0
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "新着メールなし" > "$CACHE_DIR/gmail.md"
fi

# --- Update meta.json ---
NOW=$(date -Iseconds)
python3 -c "
import json
meta = {
    'google_synced_at': '$NOW',
    'newspaper_generated_at': None,
    'calendar_events': $CAL_EVENTS,
    'gmail_messages': $GMAIL_MESSAGES
}
# Preserve existing fields
try:
    with open('$META_FILE') as f:
        existing = json.load(f)
    for k in ['newspaper_generated_at']:
        if k in existing and existing[k]:
            meta[k] = existing[k]
except Exception:
    pass
with open('$META_FILE', 'w') as f:
    json.dump(meta, f, indent=2)
"

# --- S3 sync ---
if command -v aws &>/dev/null; then
  aws s3 sync "$DATA_DIR/" "s3://$BUCKET/bochi-data/" \
    --exclude ".DS_Store" \
    --exclude "*.tmp" \
    --exclude "*.lock" \
    --size-only \
    --region ap-northeast-1 \
    --quiet 2>/dev/null || true
fi

echo "$(date -Iseconds) OK: cal=$CAL_EVENTS gmail=$GMAIL_MESSAGES errors=$ERRORS"
