#!/bin/bash
# iterm-stop-notify.sh — Notify on Claude Code response completion
#
# Only fires if Claude was processing for >10 seconds.
# Uses a timestamp marker to track when the prompt was submitted.

[[ "$TERM_PROGRAM" != "iTerm.app" ]] && exit 0

GLOW_SCRIPT="$HOME/.my_commands/iterm-notify-glow"
[[ ! -f "$GLOW_SCRIPT" ]] && exit 0

TIMESTAMP_FILE="/tmp/.iterm-claude-start"

# Check elapsed time since last prompt submission
if [[ -f "$TIMESTAMP_FILE" ]]; then
  start_ts=$(cat "$TIMESTAMP_FILE" 2>/dev/null)
  now_ts=$(date +%s)
  elapsed=$(( now_ts - start_ts ))
  rm -f "$TIMESTAMP_FILE"

  # Only notify if processing took >10 seconds
  (( elapsed < 10 )) && exit 0

  zsh "$GLOW_SCRIPT" "${elapsed}s" "0" "Claude Code" "$TTY" &
fi
exit 0
