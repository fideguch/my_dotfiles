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

# Pokeball-themed partner box: 上半赤 (Red cap) + 黒帯 (Equator) + 下半白 (White body)
# ANSI \033[K (Erase to End of Line) で背景色をターミナル端まで延長
POKEBALL_RED='\033[48;2;238;21;21m\033[1;38;2;255;255;255m'   # red bg + bold white fg
POKEBALL_BLACK='\033[48;2;0;0;0m'                              # equator black bg
POKEBALL_WHITE='\033[48;2;245;245;245m\033[38;2;26;18;0m'      # off-white bg + dark fg
RESET='\033[0m'
EOL='\033[K'

echo ""
printf "%b\n" "${POKEBALL_RED}${EOL}${RESET}"
printf "%b\n" "${POKEBALL_RED}  このセッションのパートナー: ${JP}${EOL}${RESET}"
printf "%b\n" "${POKEBALL_BLACK}${EOL}${RESET}"
printf "%b\n" "${POKEBALL_WHITE}  ぜんこくずかん No.${PADDED_ID}  ▼${TYPE}${EOL}${RESET}"
printf "%b\n" "${POKEBALL_WHITE}  🔗 ${URL}${EOL}${RESET}"
printf "%b\n" "${POKEBALL_WHITE}${EOL}${RESET}"
echo ""
