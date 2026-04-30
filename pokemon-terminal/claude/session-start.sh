#!/usr/bin/env bash
# Pokemon Claude SessionStart hook (Phase Claude)
DATA="$HOME/my_dotfiles/pokemon-terminal/data/daily-rotation.json"
[[ ! -f "$DATA" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

DAY=$(date +%j)
COUNT=$(jq '.partners | length' "$DATA")
IDX=$(( 10#$DAY % COUNT ))
EN=$(jq -r ".partners[$IDX].en" "$DATA")
JP=$(jq -r ".partners[$IDX].jp" "$DATA")
TYPE=$(jq -r ".partners[$IDX].type" "$DATA")

if command -v pokeget >/dev/null 2>&1; then
  pokeget "$EN" 2>/dev/null || true
fi
echo ""
echo "  ─────────────────────────────────────────────"
echo "   Claude Code with Pokemon Terminal"
echo "   今日のパートナー: $JP  ▼$TYPE"
echo "   ⚡ Opus 4.7 (1M context)"
echo "  ─────────────────────────────────────────────"
exit 0
