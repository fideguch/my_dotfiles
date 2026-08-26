#!/bin/bash
# claude-stop-notify.sh — macOS notification when Claude Code stops
# Sound: Pop.aiff. Mute toggle: `touch ~/.cache/claude-notify-mute` to silence,
# `rm ~/.cache/claude-notify-mute` to restore. Banner is shown either way.
# Skip in the 24/7 Discord bridge session (would chime on every reply at night)
[[ "${CLAUDE_BRIDGE:-}" == "1" ]] && exit 0
[[ "$(uname)" != "Darwin" ]] && exit 0
command -v terminal-notifier >/dev/null 2>&1 || exit 0

if [[ ! -f "$HOME/.cache/claude-notify-mute" ]]; then
  osascript -e 'do shell script "afplay /System/Library/Sounds/Pop.aiff &"' 2>/dev/null &
fi
terminal-notifier -title "Claude Code" -message "お返事できたゆ 🐧" -activate com.googlecode.iterm2 -group "claude-code-stop" &
