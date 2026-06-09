#!/usr/bin/env bash
# pokechamp-ensure-schedule.sh
# ----------------------------------------------------------------------------
# SessionStart hook for Pokemon Champions skill.
# Verify launchd jobs are registered. If any are missing, auto-run the
# setup script to restore them. This is the死活監視 layer (defense-in-depth)
# below the OS-level launchd jobs themselves.
#
# Designed to be:
#   - fast (<1s in happy-path: just 3 launchctl list calls)
#   - silent on success (no stdout pollution)
#   - fail-soft (never block Claude Code startup; exits 0 on any error)
# ----------------------------------------------------------------------------

JOBS=(
  "com.fideguch.pokechamp-fetch-usage"
  "com.fideguch.pokechamp-fetch-yt"
  "com.fideguch.pokechamp-fetch-niche"
)

SETUP_SCRIPT="/Users/fumito_ideguchi/ai-pokemen/scripts/setup_scheduled_updates.sh"
LOG_FILE="/Users/fumito_ideguchi/.claude/logs/pokechamp-ensure-schedule.log"
mkdir -p "$(dirname "$LOG_FILE")"

TS() { date '+%Y-%m-%dT%H:%M:%S%z'; }

missing=()
for label in "${JOBS[@]}"; do
  if ! launchctl list "$label" >/dev/null 2>&1; then
    missing+=("$label")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  # all good, silent exit
  exit 0
fi

echo "[$(TS)] [pokechamp] missing jobs: ${missing[*]}" | tee -a "$LOG_FILE" >&2

# auto-restore — but only if setup script exists
if [[ -x "$SETUP_SCRIPT" ]]; then
  echo "[$(TS)] [pokechamp] auto-restore via $SETUP_SCRIPT" >> "$LOG_FILE"
  bash "$SETUP_SCRIPT" >> "$LOG_FILE" 2>&1 || true
else
  echo "[$(TS)] [pokechamp] setup script missing or non-executable: $SETUP_SCRIPT" >> "$LOG_FILE"
fi

# always exit 0 — never block Claude Code startup
exit 0
