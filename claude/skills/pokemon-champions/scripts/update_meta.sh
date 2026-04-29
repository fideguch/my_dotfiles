#!/usr/bin/env bash
# Phase 3: Refresh freshness-critical meta data.
# Cron-friendly: outputs status to stdout, non-zero exit on total failure.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Updating Smogon usage stats and meta sources..."
FETCH=1 python3 lib/meta_fetcher.py "https://www.smogon.com/stats/" || echo "[WARN] smogon stats fetch had issues (check stale cache)"
FETCH=1 python3 lib/meta_fetcher.py "https://yakkun.com/sm/" || echo "[WARN] yakkun fetch had issues"

# Also try official site (may not exist yet)
FETCH=1 python3 lib/meta_fetcher.py "https://pokemonchampions.pokemon.com/" || echo "[WARN] official site not available; using cache or marking unknown"

echo "Cache contents:"
ls -la cache/
