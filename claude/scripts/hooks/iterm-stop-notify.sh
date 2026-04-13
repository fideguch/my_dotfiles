#!/bin/bash
# iterm-stop-notify.sh — Notify on Claude Code response completion
#
# Uses ONLY AppleScript 'set background image' (safe with Pokemon bg).
# Targets session by TTY path, not "current session".

[[ "$TERM_PROGRAM" != "iTerm.app" ]] && exit 0

GLOW_SCRIPT="$HOME/.my_commands/iterm-notify-glow"
[[ ! -f "$GLOW_SCRIPT" ]] && exit 0

# Pass $TTY so the glow targets the correct pane
zsh "$GLOW_SCRIPT" "" "0" "Claude Code" "$TTY" &
exit 0
