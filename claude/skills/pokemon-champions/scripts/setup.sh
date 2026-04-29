#!/usr/bin/env bash
# Pokemon Champions skill — initial setup
# Idempotent: safe to re-run.

set -euo pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Setting up pokemon-champions skill at: $SKILL_ROOT"

# 1. Verify dependencies
echo "[1/4] Checking dependencies..."
for cmd in bun python3 git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "  ERROR: $cmd not found. Please install before running setup."
    [ "$cmd" = "bun" ] && echo "  Hint: brew install bun"
    exit 1
  fi
  echo "  ✓ $cmd: $(command -v "$cmd")"
done

# 2. Install Bun deps
echo "[2/4] Installing Bun dependencies..."
cd "$SKILL_ROOT/scripts"
bun install >/dev/null 2>&1
echo "  ✓ @smogon/calc installed"

# 3. Extract Showdown data → data/*.json (skip if VERSION.json already exists)
if [ -f "$SKILL_ROOT/data/VERSION.json" ]; then
  echo "[3/4] data/VERSION.json exists — skipping data extraction (delete to force refresh)"
else
  echo "[3/4] Extracting Showdown data (this takes ~1-2 min)..."
  bun run extract_data.ts
  echo "  ✓ data/ populated"
fi

# 4. Build calc binary (skip if bin already exists)
if [ -x "$SKILL_ROOT/bin/pokechamp-calc" ]; then
  echo "[4/4] bin/pokechamp-calc exists — skipping build (delete to force rebuild)"
else
  echo "[4/4] Building calc binary..."
  bash "$SKILL_ROOT/scripts/build_calc.sh"
  echo "  ✓ bin/pokechamp-calc built ($(du -h "$SKILL_ROOT/bin/pokechamp-calc" | cut -f1))"
fi

# Smoke test
echo ""
echo "Smoke test..."
RESULT=$(echo '{"gen":9,"attacker":{"name":"Garchomp","item":"Choice Band","nature":"Jolly","evs":{"atk":252,"spe":252}},"defender":{"name":"Mimikyu","evs":{"hp":4}},"move":{"name":"Earthquake"}}' \
  | "$SKILL_ROOT/bin/pokechamp-calc" 2>&1)
if echo "$RESULT" | grep -q "guaranteed OHKO"; then
  echo "  ✓ Calc binary works (Choice Band Garchomp Earthquake → Mimikyu = guaranteed OHKO)"
else
  echo "  ✗ Smoke test FAILED:"
  echo "$RESULT"
  exit 1
fi

echo ""
echo "✅ Setup complete. Activate skill with /pokechamp in Claude Code."
