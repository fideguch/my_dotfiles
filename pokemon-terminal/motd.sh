#!/usr/bin/env bash
# Pokemon Terminal — Session Greeting MOTD (Phase β)
# Reads partner from SSOT cache populated by lib/session-pokemon.sh.
# Output: pokeget sprite + 3-line greeting (partner / dex no. / zukan URL).
# 出典: tkyko13 (公式図鑑URL連携) + sergicalsix (カタカナ名)

set -e
CACHE="$HOME/.cache/poke-session-current.json"
[[ ! -f "$CACHE" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

EN=$(jq -r '.en'   "$CACHE")
JP=$(jq -r '.jp'   "$CACHE")
ID=$(jq -r '.id'   "$CACHE")
TYPE=$(jq -r '.type' "$CACHE")
URL=$(jq -r '.url' "$CACHE")
PADDED_ID=$(printf "%04d" "$ID")

# url field is the SSOT default; fall back to format if cache predates schema.
[[ "$URL" == "null" || -z "$URL" ]] && URL="https://zukan.pokemon.co.jp/detail/${PADDED_ID}/"

if command -v pokeget >/dev/null 2>&1; then
  echo ""
  echo ""
  # --hide-name: 英語名ヘッダーを非表示 (下で日本語名 greeting で代替)
  # sed indent: 各行を 4 スペース左パディング
  pokeget --hide-name "$EN" 2>/dev/null | sed 's/^/    /' || true
fi

echo ""
echo "  このセッションのパートナー: $JP"
echo "  ぜんこくずかん No.$PADDED_ID  ▼$TYPE"
echo "  🔗 $URL"
echo ""
