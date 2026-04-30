#!/usr/bin/env bash
# Pokemon Terminal — Session Greeting MOTD (Phase β)
# シェル起動毎にランダム: $RANDOM を seed に partners ローテ
# 出典: tkyko13 (公式図鑑URL連携) + sergicalsix (カタカナ名)

set -e
DATA="$HOME/my_dotfiles/pokemon-terminal/data/daily-rotation.json"
[[ ! -f "$DATA" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

COUNT=$(jq '.partners | length' "$DATA")
IDX=$(( RANDOM % COUNT ))
EN=$(jq -r ".partners[$IDX].en" "$DATA")
JP=$(jq -r ".partners[$IDX].jp" "$DATA")
ID=$(jq -r ".partners[$IDX].id" "$DATA")
TYPE=$(jq -r ".partners[$IDX].type" "$DATA")
PADDED_ID=$(printf "%04d" "$ID")

# Cache for current shell session (read by claude statusline within same TTY)
CACHE_DIR="$HOME/.cache"
mkdir -p "$CACHE_DIR"
echo "{\"en\":\"$EN\",\"jp\":\"$JP\",\"id\":$ID,\"type\":\"$TYPE\"}" > "$CACHE_DIR/poke-session-current.json"

if command -v pokeget >/dev/null 2>&1; then
  pokeget "$EN" 2>/dev/null || true
fi

echo ""
echo "  このセッションのパートナー: $JP"
echo "  ぜんこくずかん No.$PADDED_ID  ▼$TYPE"
echo "  🔗 https://zukan.pokemon.co.jp/detail/$PADDED_ID/"
echo ""
