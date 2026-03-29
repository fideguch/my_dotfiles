#!/bin/bash
# bochi-feedback-capture.sh
# PostToolUse hook: auto-capture user feedback on bochi source quality
# Triggered on Write|Edit tools, filters to bochi-related file paths only
# Input: JSON on stdin from Claude Code (tool_input, tool_response)

set -euo pipefail

BOCHI_REFS_DIR="$HOME/.claude/skills/bochi-skill/references"
FEEDBACK_LOG="$BOCHI_REFS_DIR/feedback-log.md"
LEARNED_SOURCES="$BOCHI_REFS_DIR/learned-sources.md"
TODAY=$(date +%Y-%m-%d)

# Read JSON from stdin (Claude Code passes tool context via stdin)
INPUT=$(cat 2>/dev/null || echo "")
if [[ -z "$INPUT" ]]; then
  exit 0
fi

# Extract file_path from stdin JSON using jq (preferred) or python3 fallback
FILE_PATH=""
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // ""' 2>/dev/null || echo "")
else
  FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('tool_input',{}).get('file_path','') or d.get('tool_response',{}).get('filePath',''))
except:
    print('')
" 2>/dev/null || echo "")
fi

# Guard: only process bochi-related file writes
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi
if [[ "$FILE_PATH" != *"docs/bochi/"* ]] && [[ "$FILE_PATH" != *"bochi-skill/references/"* ]]; then
  exit 0
fi

# Extract content from tool_input for feedback signal detection
CONTENT=""
if command -v jq &>/dev/null; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // ""' 2>/dev/null || echo "")
else
  CONTENT=$(echo "$INPUT" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    ti=d.get('tool_input',{})
    print(ti.get('content','') or ti.get('new_string',''))
except:
    print('')
" 2>/dev/null || echo "")
fi

if [[ -z "$CONTENT" ]]; then
  exit 0
fi

# Check for feedback signals in the actual content (not raw JSON)
POSITIVE_SIGNALS="いい|使える|参考になる|良い|great|useful|helpful|perfect|ナイス|最高"
NEGATIVE_SIGNALS="違う|微妙|的外れ|wrong|incorrect|bad|ダメ|不正確"

if echo "$CONTENT" | grep -qiE "$POSITIVE_SIGNALS" 2>/dev/null; then
  echo "$TODAY | positive | $FILE_PATH | Auto-detected positive feedback" >> "$FEEDBACK_LOG"
fi

if echo "$CONTENT" | grep -qiE "$NEGATIVE_SIGNALS" 2>/dev/null; then
  echo "$TODAY | negative | $FILE_PATH | Auto-detected negative feedback" >> "$FEEDBACK_LOG"
fi

exit 0
