#!/usr/bin/env bash
# Skill & symlink health check for Claude Code SessionStart hook
# Performance target: <2s (no network calls)

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
ISSUES=()

# 1. Broken symlinks in skills/
while IFS= read -r broken; do
  ISSUES+=("BROKEN_SYMLINK: $broken")
done < <(find "$SKILLS_DIR" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null)

# 2. Core directories must be symlinks (not copies)
for dir in rules agents hooks commands; do
  target="$CLAUDE_DIR/$dir"
  if [[ -d "$target" ]] && [[ ! -L "$target" ]]; then
    ISSUES+=("NOT_SYMLINK: ~/.claude/$dir is a directory, not a symlink (possible Claude Edit breakage)")
  fi
done

# 3. Self-authored repos: check for uncommitted changes (fast: --porcelain)
for repo in bochi pm-data-analysis speckit-bridge my_pm_tools; do
  repo_dir="$SKILLS_DIR/$repo"
  if [[ -d "$repo_dir/.git" ]]; then
    dirty=$(cd "$repo_dir" && git status --porcelain 2>/dev/null | head -1)
    if [[ -n "$dirty" ]]; then
      ISSUES+=("DIRTY_REPO: ~/.claude/skills/$repo has uncommitted changes")
    fi
  fi
done

# 4. Git-unmanaged skills warning (Type D)
for skill_dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$skill_dir")
  if [[ ! -L "${skill_dir%/}" ]] && [[ ! -d "$skill_dir/.git" ]]; then
    ISSUES+=("NO_GIT: ~/.claude/skills/$name is not symlinked and has no .git")
  fi
done

# Output
if [[ ${#ISSUES[@]} -eq 0 ]]; then
  echo "✅ Skill health: all checks passed"
else
  echo "⚠ Skill health: ${#ISSUES[@]} issue(s) found"
  for issue in "${ISSUES[@]}"; do
    echo "  - $issue"
  done
fi
