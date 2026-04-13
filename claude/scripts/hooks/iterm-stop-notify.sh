#!/bin/bash
# iterm-stop-notify.sh — Notify on Claude Code response completion
#
# Fires the same gradual pulse + tint animation as terminal commands.
# Uses ONLY AppleScript 'set background image' (safe with Pokemon bg).
# OSC escape sequences are NEVER used here.

# Only run in iTerm2
[[ "$TERM_PROGRAM" != "iTerm.app" ]] && exit 0

# iterm-notify-glow is a zsh script in ~/.my_commands/
GLOW_SCRIPT="$HOME/.my_commands/iterm-notify-glow"
[[ ! -f "$GLOW_SCRIPT" ]] && exit 0

# Fire the notification (exit_code=0 → blue tint for normal completion)
zsh "$GLOW_SCRIPT" "" "0" "Claude Code" &
exit 0
