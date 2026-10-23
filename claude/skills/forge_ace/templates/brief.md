# forge_ace brief — <run name>

<!-- Written once by the orchestrator at Step 0. Every agent reads this file first instead of a long inline prompt.
     Keep it current: when the requirement or scope changes, edit here and note the date. -->

## Requirement (user's words, verbatim)

- YYYY-MM-DD: "…"

## Spec / plan

- Plan: `reports/00-planner.md` (or link to spec)
- Acceptance: …

## Scope

| File | Change |
|---|---|
| `…` | … |

Out of scope: …

## Constraints

- Do not write to: …
- Rollback: copies of the touched files in `<path>`

## Commands

- Tests: `…`
- Real-data check (read-only): `…`

## Environment notes (this machine)

- Shell aliases: `cd` also lists files, `cp` asks before overwrite, `diff` prints unified diffs → use absolute paths / `builtin cd`, `command cp`, `command diff`
- Python: always `-B` inside skill folders (a test fails on `__pycache__`)
- The Obsidian CLI can hang while Obsidian re-indexes after large moves; do not call it from agents unless the brief says so
- Never run tests that write `/tmp/.forge-ace-session.json` or the real outcome log: tests set `FORGE_ACE_SESSION_FILE`, `FORGE_ACE_OUTCOMES_DIR`, `FORGE_ACE_FALLBACK_DIR`
- Never override `HOME` when calling `node` (the Volta shim re-launches itself recursively)
