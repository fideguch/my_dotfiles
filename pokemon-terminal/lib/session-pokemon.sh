#!/usr/bin/env bash
# Pokemon Terminal — Session SSOT picker (Phase β prerequisite)
# Runs ONCE per shell. Writes ~/.cache/poke-session-current.json (5-field schema)
# and pre-renders krabby art to ~/.cache/poke-session-art.txt for starship cat.
#
# Schema:
#   {"en":"garchomp","jp":"ガブリアス","id":445,"type":"ドラゴン/じめん",
#    "url":"https://zukan.pokemon.co.jp/detail/0445/"}
#
# Consumers (read-only): motd.sh, claude/session-start.sh, starship.toml [custom.pokemon]
#
# Sourced from .zshrc BEFORE motd.sh block. Guarded by $_POKE_SESSION_DONE.

# Idempotency guard (re-source safe)
[[ -n "$_POKE_SESSION_DONE" ]] && return 0

# Hard requirement: jq. Graceful no-op if missing (consumers fall back).
command -v jq >/dev/null 2>&1 || return 0

_POKE_DATA="$HOME/my_dotfiles/pokemon-terminal/data/daily-rotation.json"
[[ ! -f "$_POKE_DATA" ]] && return 0

_POKE_CACHE_DIR="$HOME/.cache"
mkdir -p "$_POKE_CACHE_DIR"

# Per-session $RANDOM pick from data/daily-rotation.json
_POKE_COUNT=$(jq '.partners | length' "$_POKE_DATA")
_POKE_IDX=$(( RANDOM % _POKE_COUNT ))
_POKE_EN=$(jq -r ".partners[$_POKE_IDX].en"   "$_POKE_DATA")
_POKE_JP=$(jq -r ".partners[$_POKE_IDX].jp"   "$_POKE_DATA")
_POKE_ID=$(jq -r ".partners[$_POKE_IDX].id"   "$_POKE_DATA")
_POKE_TYPE=$(jq -r ".partners[$_POKE_IDX].type" "$_POKE_DATA")
_POKE_PADDED_ID=$(printf "%04d" "$_POKE_ID")
_POKE_URL="https://zukan.pokemon.co.jp/detail/${_POKE_PADDED_ID}/"

# Write JSON cache (5-field SUPERSET: en/jp/id/type/url)
# jq -n ensures correct escaping of JP characters and quoting.
jq -n \
  --arg en   "$_POKE_EN" \
  --arg jp   "$_POKE_JP" \
  --argjson id "$_POKE_ID" \
  --arg type "$_POKE_TYPE" \
  --arg url  "$_POKE_URL" \
  '{en:$en, jp:$jp, id:$id, type:$type, url:$url}' \
  > "$_POKE_CACHE_DIR/poke-session-current.json"

# Note: krabby ASCII art pre-render は v2.1 で廃止。
# 理由: starship right_format は multi-line 出力をサポートしないため、
# 3行の krabby silhouette は表示されなかった。代替: motd.sh で pokeget 全身表示。
# 必要なら別途 precmd hook で復活可能 (cache file は廃止)。

# Internal cleanup (don't pollute interactive shell namespace)
unset _POKE_DATA _POKE_CACHE_DIR _POKE_COUNT _POKE_IDX
unset _POKE_EN _POKE_JP _POKE_ID _POKE_TYPE _POKE_PADDED_ID _POKE_URL

# Mark session as picked (consumers read cache, do not re-pick)
export _POKE_SESSION_DONE=1
