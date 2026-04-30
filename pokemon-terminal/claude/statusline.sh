#!/usr/bin/env bash
# Pokemon Claude statusLine (Phase Claude)
# Read partner from cache (written by session-start.sh, stable per session)
# Fallback chain: claude cache → shell session cache → motd random
CACHE_CLAUDE="$HOME/.cache/poke-claude-current.json"
CACHE_SHELL="$HOME/.cache/poke-session-current.json"
DATA="$HOME/my_dotfiles/pokemon-terminal/data/daily-rotation.json"

CWD=$(pwd | sed "s|$HOME|~|")
NOW=$(date +%H:%M)

if [[ -f "$CACHE_CLAUDE" ]] && command -v jq >/dev/null 2>&1; then
  JP=$(jq -r '.jp' "$CACHE_CLAUDE")
  TYPE=$(jq -r '.type' "$CACHE_CLAUDE")
elif [[ -f "$CACHE_SHELL" ]] && command -v jq >/dev/null 2>&1; then
  JP=$(jq -r '.jp' "$CACHE_SHELL")
  TYPE=$(jq -r '.type' "$CACHE_SHELL")
elif [[ -f "$DATA" ]] && command -v jq >/dev/null 2>&1; then
  COUNT=$(jq '.partners | length' "$DATA")
  IDX=$(( RANDOM % COUNT ))
  JP=$(jq -r ".partners[$IDX].jp" "$DATA")
  TYPE=$(jq -r ".partners[$IDX].type" "$DATA")
else
  echo "⚡ Claude $NOW"
  exit 0
fi

echo "⚡ $JP Lv.50 ▼$TYPE  $CWD  $NOW"
