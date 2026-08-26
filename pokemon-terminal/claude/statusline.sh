#!/usr/bin/env bash
# Claude Code statusLine — token quota gauges (2-line, fuel-gauge style)
#   Line 1: 5-hour window remaining (gauge + reset time + countdown)
#   Line 2: weekly remaining — overall + model-scoped (e.g. Fable) + cwd/time
#
# Data sources:
#   - stdin JSON from Claude Code: rate_limits.five_hour / seven_day (official)
#   - OAuth usage API for the model-scoped weekly window (not in stdin):
#     cached 60s at ~/.cache/claude-usage-api.json, refreshed in background
#
# Gauge: filled blocks = REMAINING. Colors: green >=50%, yellow >=20%, red <20%.

CACHE_API="$HOME/.cache/claude-usage-api.json"
LOCK_API="$HOME/.cache/claude-usage-api.lock"
API_TTL=60

INPUT=$(cat)
NOW_EPOCH=$(date +%s)
NOW=$(date +%H:%M)

command -v jq >/dev/null 2>&1 || { echo "⚡ Claude $NOW"; exit 0; }

# --- stdin fields (single jq call, tab-separated) ---
IFS=$'\t' read -r FH_REM FH_RESET WK_REM WK_RESET CWD <<< "$(printf '%s' "$INPUT" | jq -r '
  def rem(x): if x == null then "-" else ((100 - x) | round | tostring) end;
  [ rem(.rate_limits.five_hour.used_percentage),
    (.rate_limits.five_hour.resets_at // "-" | tostring),
    rem(.rate_limits.seven_day.used_percentage),
    (.rate_limits.seven_day.resets_at // "-" | tostring),
    (.workspace.current_dir // "-") ] | @tsv')"

CWD_DISP=${CWD/#$HOME/\~}
[[ "$CWD_DISP" == "-" ]] && CWD_DISP=$(pwd | sed "s|$HOME|~|")

# --- background refresh of the usage API cache (model-scoped weekly) ---
refresh_api_cache() {
  local age=999999 lock_age=999999
  [[ -f "$CACHE_API" ]] && age=$(( NOW_EPOCH - $(stat -f %m "$CACHE_API" 2>/dev/null || echo 0) ))
  (( age < API_TTL )) && return
  [[ -f "$LOCK_API" ]] && lock_age=$(( NOW_EPOCH - $(stat -f %m "$LOCK_API" 2>/dev/null || echo 0) ))
  (( lock_age < 120 )) && return
  touch "$LOCK_API"
  (
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
      | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    [[ -z "$token" && -f "$HOME/.claude/.credentials.json" ]] && \
      token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
    if [[ -n "$token" ]]; then
      out=$(curl -sS --max-time 4 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)
      if printf '%s' "$out" | jq -e '.limits' >/dev/null 2>&1; then
        printf '%s' "$out" > "$CACHE_API.tmp" && mv "$CACHE_API.tmp" "$CACHE_API"
      fi
    fi
    rm -f "$LOCK_API"
  ) >/dev/null 2>&1 &
}
refresh_api_cache

# --- model-scoped weekly (e.g. Fable) from cache ---
SC_NAME="" ; SC_REM=""
if [[ -f "$CACHE_API" ]]; then
  IFS=$'\t' read -r SC_NAME SC_REM <<< "$(jq -r '
    ([.limits[]? | select(.kind == "weekly_scoped")] | first) as $s
    | if $s == null then "\t"
      else [($s.scope.model.display_name // "Model"),
            ((100 - $s.percent) | round | tostring)] | @tsv end' \
    "$CACHE_API" 2>/dev/null)"
fi

# --- helpers ---
RESET=$'\033[0m'
color_for() {  # $1: remaining percent
  if   (( $1 >= 50 )); then printf '\033[32m'
  elif (( $1 >= 20 )); then printf '\033[33m'
  else                      printf '\033[31m'; fi
}
gauge() {  # $1: remaining percent -> 10-block fuel gauge
  local filled=$(( ($1 + 5) / 10 )) bar="" i
  (( filled > 10 )) && filled=10 ; (( filled < 0 )) && filled=0
  for (( i=0; i<filled; i++ )); do bar+="▓"; done
  for (( i=filled; i<10; i++ )); do bar+="░"; done
  printf '%s' "$bar"
}
wday_jp() { case "$1" in 1) echo 月;; 2) echo 火;; 3) echo 水;; 4) echo 木;; 5) echo 金;; 6) echo 土;; 7) echo 日;; esac; }
countdown() {  # $1: reset epoch -> human-readable remaining
  local mins=$(( ($1 - NOW_EPOCH + 59) / 60 ))
  (( mins < 0 )) && mins=0
  if   (( mins < 60 ));   then echo "あと${mins}分"
  elif (( mins < 1440 )); then echo "あと$((mins/60))時間$((mins%60))分"
  else                         echo "あと$((mins/1440))日"; fi
}

# --- render ---
if [[ "$FH_REM" == "-" || -z "$FH_REM" ]]; then
  # rate_limits absent until the first API response in the session
  echo "⚡ usage計測待ち…  $CWD_DISP  $NOW"
  exit 0
fi

FH_TIME=$(date -r "$FH_RESET" +%H:%M 2>/dev/null || echo "?")
FH_C=$(color_for "$FH_REM")
LINE1="⚡ 5h ${FH_C}$(gauge "$FH_REM")${RESET} 残${FH_REM}% (${FH_TIME} · $(countdown "$FH_RESET"))"

if [[ "$WK_REM" != "-" && -n "$WK_REM" ]]; then
  WK_M=$(date -r "$WK_RESET" +%m 2>/dev/null); WK_D=$(date -r "$WK_RESET" +%d 2>/dev/null)
  WK_DATE="${WK_M#0}/${WK_D#0}($(wday_jp "$(date -r "$WK_RESET" +%u 2>/dev/null)")) $(date -r "$WK_RESET" +%H:%M 2>/dev/null)"
  WK_C=$(color_for "$WK_REM")
  LINE2="🗓 週 全体 ${WK_C}$(gauge "$WK_REM")${RESET} ${WK_REM}%"
  if [[ -n "$SC_REM" ]]; then
    SC_C=$(color_for "$SC_REM")
    LINE2+=" | ${SC_NAME} ${SC_C}$(gauge "$SC_REM")${RESET} ${SC_REM}%"
  fi
  LINE2+=" (${WK_DATE})  $CWD_DISP  $NOW"
else
  LINE2="🗓 週 –  $CWD_DISP  $NOW"
fi

echo "$LINE1"
echo "$LINE2"
