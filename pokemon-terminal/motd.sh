#!/usr/bin/env bash
# Pokemon Terminal — Daily Greeting MOTD (Phase β)
# 日替わり固定: date +%j を seed に partners ローテ
# 出典: tkyko13 (公式図鑑URL連携) + sergicalsix (カタカナ名)

set -e
DATA="$HOME/my_dotfiles/pokemon-terminal/data/daily-rotation.json"
[[ ! -f "$DATA" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

DAY=$(date +%j)
COUNT=$(jq '.partners | length' "$DATA")
IDX=$(( 10#$DAY % COUNT ))
EN=$(jq -r ".partners[$IDX].en" "$DATA")
JP=$(jq -r ".partners[$IDX].jp" "$DATA")
ID=$(jq -r ".partners[$IDX].id" "$DATA")
TYPE=$(jq -r ".partners[$IDX].type" "$DATA")
PADDED_ID=$(printf "%04d" "$ID")

if command -v pokeget >/dev/null 2>&1; then
  pokeget "$EN" 2>/dev/null || true
fi

echo ""
echo "  今日のパートナー: $JP"
echo "  ぜんこくずかん No.$PADDED_ID  ▼$TYPE"
echo "  🔗 https://zukan.pokemon.co.jp/detail/$PADDED_ID/"
echo ""
