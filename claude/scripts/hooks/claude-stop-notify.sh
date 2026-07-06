#!/bin/bash
# claude-stop-notify.sh — macOS notification when Claude Code stops
# Skip in the 24/7 Discord bridge session (would chime on every reply at night)
[[ "${CLAUDE_BRIDGE:-}" == "1" ]] && exit 0
[[ "$(uname)" != "Darwin" ]] && exit 0
command -v terminal-notifier >/dev/null 2>&1 || exit 0

osascript -e 'do shell script "afplay /System/Library/Sounds/Glass.aiff &"' 2>/dev/null &
terminal-notifier -title "Claude Code" -message "お返事できたゆ 🐧" -activate com.googlecode.iterm2 -group "claude-code-stop" &
