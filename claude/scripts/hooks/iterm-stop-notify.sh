#!/bin/bash
# iterm-stop-notify.sh — Notify when Claude Code needs user attention
#
# Fires on every Stop event (response complete, question, approval request).
# iterm-notify-glow handles the focus check: if user is already watching
# the Claude pane, it skips entirely.
#
# TTY resolution: uses AppleScript at the moment of firing.
# In split-pane setups, this returns the focused pane's TTY.
# The glow script's focus check ensures it only runs when user is NOT
# looking at the Claude pane.

[[ "$TERM_PROGRAM" != "iTerm.app" ]] && exit 0

GLOW_SCRIPT="$HOME/.my_commands/iterm-notify-glow"
[[ ! -f "$GLOW_SCRIPT" ]] && exit 0

# Get TTY of the session that triggered this hook.
# At Stop time, Claude's session may or may not be focused.
# Read from saved file if available, otherwise use current focus as fallback.
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
TTY_FILE="/tmp/.iterm-claude-tty-${SESSION_ID}"

if [[ -f "$TTY_FILE" ]]; then
  MY_TTY=$(cat "$TTY_FILE" 2>/dev/null)
else
  MY_TTY=$(osascript -e 'tell application "iTerm2" to return tty of current session of current tab of current window' 2>/dev/null)
fi
[[ -z "$MY_TTY" ]] && exit 0

# nohup + disown ensures the child process survives this script's exit
nohup zsh "$GLOW_SCRIPT" "" "0" "Claude Code" "$MY_TTY" >/dev/null 2>&1 &
disown
