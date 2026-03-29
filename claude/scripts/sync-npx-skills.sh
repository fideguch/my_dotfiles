#!/usr/bin/env bash
set -euo pipefail

# Sync npx-installed skills from ~/.agents/skills/ to ~/.claude/skills/
# Creates relative symlinks only for entries that don't already exist in target.

AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"
LINKED=0
SKIPPED=0

if [[ ! -d "$AGENTS_DIR" ]]; then
  echo "⚠ ~/.agents/skills/ not found. Run 'npx skills add' first."
  exit 0
fi

for skill_dir in "$AGENTS_DIR"/*/; do
  [[ ! -d "$skill_dir" ]] && continue
  name=$(basename "$skill_dir")
  target="$CLAUDE_DIR/$name"

  if [[ -e "$target" ]] || [[ -L "$target" ]]; then
    ((SKIPPED++))
  else
    ln -s "../../.agents/skills/$name" "$target"
    echo "  LINKED: $name"
    ((LINKED++))
  fi
done

echo "npx skill sync: $LINKED linked, $SKIPPED skipped (already exist)"
