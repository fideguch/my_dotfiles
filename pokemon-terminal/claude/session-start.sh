#!/usr/bin/env bash
# Pokemon Claude SessionStart hook (Phase Claude)
# Claude セッション起動毎にランダム、cache に書いて statusline と共有
DATA="$HOME/my_dotfiles/pokemon-terminal/data/daily-rotation.json"
[[ ! -f "$DATA" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

COUNT=$(jq '.partners | length' "$DATA")
IDX=$(( RANDOM % COUNT ))
EN=$(jq -r ".partners[$IDX].en" "$DATA")
JP=$(jq -r ".partners[$IDX].jp" "$DATA")
TYPE=$(jq -r ".partners[$IDX].type" "$DATA")

# Claude session cache (read by statusline.sh, stable per Claude session)
CACHE_DIR="$HOME/.cache"
mkdir -p "$CACHE_DIR"
echo "{\"en\":\"$EN\",\"jp\":\"$JP\",\"type\":\"$TYPE\"}" > "$CACHE_DIR/poke-claude-current.json"

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
