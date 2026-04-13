#!/bin/bash
# iterm-session-start-notify.sh — Save Claude session's TTY at startup
#
# At SessionStart, the Claude pane IS the focused session.
# We capture its TTY now so the Stop hook can target it later,
# even when the user has switched to a different pane.

[[ "$TERM_PROGRAM" != "iTerm.app" ]] && exit 0

# Read session_id from stdin JSON
SESSION_ID=""
if read -t 2 input_json; then
  SESSION_ID=$(echo "$input_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
fi
# Fallback to env var
[[ -z "$SESSION_ID" ]] && SESSION_ID="$CLAUDE_SESSION_ID"
[[ -z "$SESSION_ID" ]] && SESSION_ID="default"

# At startup, current session = Claude's session
MY_TTY=$(osascript -e 'tell application "iTerm2" to return tty of current session of current tab of current window' 2>/dev/null)
[[ -z "$MY_TTY" ]] && exit 0

echo "$MY_TTY" > "/tmp/.iterm-claude-tty-${SESSION_ID}"
exit 0
