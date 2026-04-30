#!/usr/bin/env bash
# Pokemon Claude statusLine (Phase Claude)
DATA="$HOME/my_dotfiles/pokemon-terminal/data/daily-rotation.json"
[[ ! -f "$DATA" ]] && { echo "⚡ Claude $(date +%H:%M)"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "⚡ Claude $(date +%H:%M)"; exit 0; }

DAY=$(date +%j)
COUNT=$(jq '.partners | length' "$DATA")
IDX=$(( 10#$DAY % COUNT ))
JP=$(jq -r ".partners[$IDX].jp" "$DATA")
TYPE=$(jq -r ".partners[$IDX].type" "$DATA")
CWD=$(pwd | sed "s|$HOME|~|")

echo "⚡ $JP Lv.50 ▼$TYPE  $CWD  $(date +%H:%M)"
