#!/bin/bash
# iterm-stop-notify.sh — Notify when Claude Code needs user attention
#
# Fires on every Stop event (response complete, question, approval request).
# iterm-notify-glow handles the focus check: if user is already watching
# the Claude pane, it skips. If user is in another pane, it swaps Pokemon.
#
# TTY source: saved by iterm-session-start-notify.sh at SessionStart.

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

zsh "$GLOW_SCRIPT" "" "0" "Claude Code" "$MY_TTY" &
exit 0
