#!/bin/bash
# Weekly health check: SSH to Lightsail and run bochi S3 round-trip test.
# Triggered by: ~/Library/LaunchAgents/com.fideguch.bochi-healthcheck.plist (Mon 09:00 JST)
# Reads (read-only): ~/.claude/skills/bochi/tests/s3-sync-test.sh
# Writes:            ~/.claude/logs/bochi-healthcheck.log
set -uo pipefail

LOG_FILE="$HOME/.claude/logs/bochi-healthcheck.log"
LIGHTSAIL_HOST="ubuntu@54.249.49.69"
TEST_SCRIPT="$HOME/.claude/skills/bochi/tests/s3-sync-test.sh"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_MAX_SIZE=$((10 * 1024 * 1024))

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# 10MB rotate
if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(stat -f %z "$LOG_FILE" 2>/dev/null || stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$LOG_SIZE" -gt "$LOG_MAX_SIZE" ]; then
    mv "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
    gzip -f "$LOG_FILE.1" 2>/dev/null || true
  fi
fi

if [ ! -f "$TEST_SCRIPT" ]; then
  printf '=== %s healthcheck ABORT: test script missing at %s ===\n' "$TIMESTAMP" "$TEST_SCRIPT" >> "$LOG_FILE"
  exit 1
fi

printf '\n=== %s healthcheck start ===\n' "$TIMESTAMP" >> "$LOG_FILE"

# Non-interactive SSH for launchd context (no ssh-agent / SSH_AUTH_SOCK)
SSH_OUTPUT=$(/usr/bin/ssh \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=15 \
  "$LIGHTSAIL_HOST" 'bash -s' < "$TEST_SCRIPT" 2>&1)
SSH_EXIT=$?

printf '%s\n' "$SSH_OUTPUT" >> "$LOG_FILE"
END_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '=== %s healthcheck end exit=%d ===\n' "$END_TIMESTAMP" "$SSH_EXIT" >> "$LOG_FILE"

if [ "$SSH_EXIT" -ne 0 ]; then
  osascript -e "display notification \"bochi weekly healthcheck failed (exit ${SSH_EXIT}). See ~/.claude/logs/bochi-healthcheck.log\" with title \"bochi Healthcheck Alert\"" 2>/dev/null || true
fi

exit "$SSH_EXIT"
