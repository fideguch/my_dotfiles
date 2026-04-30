#!/usr/bin/env bash
# Pokemon Claude SessionStart hook (Phase Claude)
# SSOT-aware: prefers shell-session cache (consistent partner across MOTD/prompt/claude).
# Falls back to own random pick if claude is launched outside an interactive zsh.
DATA="$HOME/my_dotfiles/pokemon-terminal/data/daily-rotation.json"
CACHE_SHELL="$HOME/.cache/poke-session-current.json"
CACHE_CLAUDE="$HOME/.cache/poke-claude-current.json"
command -v jq >/dev/null 2>&1 || exit 0

mkdir -p "$HOME/.cache"

if [[ -f "$CACHE_SHELL" ]]; then
  # SSOT path: mirror shell-session partner to claude cache so statusline.sh
  # continues working unchanged. Preserve full schema (en/jp/id/type/url).
  EN=$(jq -r '.en'   "$CACHE_SHELL")
  JP=$(jq -r '.jp'   "$CACHE_SHELL")
  TYPE=$(jq -r '.type' "$CACHE_SHELL")
  cp "$CACHE_SHELL" "$CACHE_CLAUDE"
elif [[ -f "$DATA" ]]; then
  # Fallback: claude launched outside zsh (no shell SSOT). Pick our own.
  COUNT=$(jq '.partners | length' "$DATA")
  IDX=$(( RANDOM % COUNT ))
  EN=$(jq -r ".partners[$IDX].en"   "$DATA")
  JP=$(jq -r ".partners[$IDX].jp"   "$DATA")
  TYPE=$(jq -r ".partners[$IDX].type" "$DATA")
  echo "{\"en\":\"$EN\",\"jp\":\"$JP\",\"type\":\"$TYPE\"}" > "$CACHE_CLAUDE"
else
  exit 0
fi

if command -v pokeget >/dev/null 2>&1; then
  pokeget "$EN" 2>/dev/null || true
fi
echo ""
echo "  ─────────────────────────────────────────────"
echo "   Claude Code with Pokemon Terminal"
echo "   このセッションのパートナー: $JP  ▼$TYPE"
echo "   ⚡ Opus 4.7 (1M context)"
echo "  ─────────────────────────────────────────────"
exit 0
