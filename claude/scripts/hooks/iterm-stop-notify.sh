#!/bin/bash
# iterm-stop-notify.sh — Notify on Claude Code response completion
#
# Reads the TTY saved by iterm-session-start-notify.sh (SessionStart hook).
# Only fires if Claude was processing for >10 seconds.
# The TTY is the pane where Claude is running, not the currently focused pane.

[[ "$TERM_PROGRAM" != "iTerm.app" ]] && exit 0

GLOW_SCRIPT="$HOME/.my_commands/iterm-notify-glow"
[[ ! -f "$GLOW_SCRIPT" ]] && exit 0

# Resolve session ID
SESSION_ID="${CLAUDE_SESSION_ID:-default}"

# Read Claude pane's TTY (saved at SessionStart)
TTY_FILE="/tmp/.iterm-claude-tty-${SESSION_ID}"
[[ ! -f "$TTY_FILE" ]] && exit 0
MY_TTY=$(cat "$TTY_FILE" 2>/dev/null)
[[ -z "$MY_TTY" ]] && exit 0

# Check elapsed time since last prompt
TIMESTAMP_FILE="/tmp/.iterm-claude-start"
if [[ -f "$TIMESTAMP_FILE" ]]; then
  start_ts=$(cat "$TIMESTAMP_FILE" 2>/dev/null)
  now_ts=$(date +%s)
  elapsed=$(( now_ts - start_ts ))
  rm -f "$TIMESTAMP_FILE"

  (( elapsed < 10 )) && exit 0
else
  # No timestamp = can't determine duration, skip
  exit 0
fi

zsh "$GLOW_SCRIPT" "${elapsed}s" "0" "Claude Code" "$MY_TTY" &
exit 0
