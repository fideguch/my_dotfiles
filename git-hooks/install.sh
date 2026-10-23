#!/usr/bin/env bash
# Install public-guard into git repositories (default: this repository), or check that it is active.
# Usage: git-hooks/install.sh [<repo>...]
#        git-hooks/install.sh --check [<repo>...]
# Installing sets core.hooksPath to this folder. A repository that already has its own hooks
# (another core.hooksPath, or files in its hooks folder) is left alone and reported.
set -euo pipefail

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
mode="install"
if [ "${1:-}" = "--check" ]; then
  mode="check"
  shift
fi
if [ "$#" -gt 0 ]; then
  repos=("$@")
else
  repos=("$(cd "$HOOKS/.." && pwd -P)")
fi

# Physical path of a folder as git would use it (relative paths are relative to the repository).
resolve() {
  (cd "$1" 2>/dev/null && cd "$2" 2>/dev/null && pwd -P) || printf '%s\n' "$2"
}

# The hooks folder git uses, resolved; empty when core.hooksPath is unset or points at the default folder.
# A relative core.hooksPath is relative to the top of the working tree; `~` is expanded as git does.
current_hooks() {
  local repo="$1" common top current
  common="$(resolve "$repo" "$(git -C "$repo" rev-parse --git-common-dir)")"
  top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$repo")"
  current="$(git -C "$repo" config --get core.hooksPath || true)"
  current="${current/#\~/$HOME}"
  [ -n "$current" ] && current="$(resolve "$top" "$current")"
  [ "$current" = "$(resolve "$top" "$common/hooks")" ] && current=""
  printf '%s\n' "$current"
}

# A public-guard folder that moved: another copy of these hooks, or a missing folder named git-hooks.
stale_guard_path() {
  local path="$1"
  [ -f "$path/public_guard.py" ] && return 0
  case "$path" in
    */git-hooks) [ ! -d "$path" ] ;;
    *) return 1 ;;
  esac
}

install_one() {
  local repo="$1" common current own=""
  common="$(resolve "$repo" "$(git -C "$repo" rev-parse --git-common-dir)")"
  current="$(current_hooks "$repo")"
  if [ -n "$current" ] && [ "$current" != "$HOOKS" ]; then
    if stale_guard_path "$current"; then
      echo "replacing a stale public-guard path ($current): $repo" >&2
    else
      echo "skip (has its own core.hooksPath $current): $repo" >&2
      return 0
    fi
  fi
  if [ -d "$common/hooks" ]; then
    own="$(find "$common/hooks" -maxdepth 1 -type f ! -name '*.sample' 2>/dev/null | head -1 || true)"
  fi
  if [ -n "$own" ]; then
    echo "skip (has its own hooks in $common/hooks): $repo" >&2
    return 0
  fi
  git -C "$repo" config --local core.hooksPath "$HOOKS"
  echo "installed: $repo"
}

check_one() {
  local repo="$1" current
  current="$(current_hooks "$repo")"
  if [ "$current" != "$HOOKS" ]; then
    echo "not installed: $repo (core.hooksPath=${current:-unset})"
    return 1
  fi
  for hook in pre-commit commit-msg pre-push; do
    if [ ! -x "$HOOKS/$hook" ]; then
      echo "broken: $repo ($HOOKS/$hook is missing or not executable)"
      return 1
    fi
  done
  echo "ok: $repo"
}

status=0
for repo in "${repos[@]}"; do
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    echo "skip (not a git repository): $repo" >&2
    [ "$mode" = "check" ] && status=1
    continue
  fi
  if [ "$mode" = "check" ]; then
    check_one "$repo" || status=1
  else
    install_one "$repo"
  fi
done

if ! python3 -I -B "$HOOKS/public_guard.py" count >/dev/null 2>&1; then
  echo "note: public_guard.py could not run (is python3 installed?)" >&2
  status=1
elif python3 -I -B "$HOOKS/public_guard.py" count | grep -q '^0 terms'; then
  echo "note: no terms in ${PUBLIC_GUARD_CONFIG_DIR:-$HOME/.config/public-guard} yet — commits stop until the lists exist (see git-hooks/README.md)" >&2
fi
exit "$status"
