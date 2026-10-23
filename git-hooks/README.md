# public-guard

Git hooks that stop client/company names and secrets from reaching a **public** repository.

| Hook | Checks |
|---|---|
| `pre-commit` | added lines and names of the staged files (also binary, empty, renamed files and symlink targets) |
| `commit-msg` | the commit message (comment lines and the part below the scissors line are ignored, as git's default cleanup does; with `--cleanup=verbatim` such lines stay in the message and `pre-push` checks them) |
| `pre-push` | branch and tag names, annotated tag messages, and every commit about to be pushed: added lines, file names, commit messages |
| `pre-commit`, `pre-push` | secrets with [gitleaks](https://github.com/gitleaks/gitleaks) (values are redacted) |

`python3 git-hooks/public_guard.py files` audits every tracked file; `python3 git-hooks/public_guard.py count` prints how many terms are loaded (never the terms).

## Install and check

```bash
git-hooks/install.sh                      # this repository
git-hooks/install.sh ~/some-public-repo   # other repositories (sets core.hooksPath to this folder)
git-hooks/install.sh --check [<repo>...]  # is it active? (exit 1 when a repository is not covered)
```

`set_up.sh` installs it into this repository and the skill repositories it clones. Repositories that already use their own hooks (including a global `core.hooksPath`) are skipped. `core.hooksPath` is an absolute path: after moving this repository, run `install.sh` again — a path that no longer exists, or another copy of these hooks, is replaced (`--check` reports repositories that are not covered).

gitleaks is expected (`brew install gitleaks`); without it the hooks warn and check names only.

## Term lists (local only — never commit them)

The names to block are private, so they live outside the repository, in `~/.config/public-guard/` (or `$PUBLIC_GUARD_CONFIG_DIR`):

| File | Content |
|---|---|
| `denylist.txt` | one term per line (`#` starts a comment) |
| `sources.txt` | glob patterns of folders whose names are terms (for example the client folders of a notes vault), so new clients are covered automatically. A leading `NNN-` is stripped; `NN-` folders and everything below them are skipped |
| `allowlist.txt` | a generic word that is also a folder name (no longer a term), or a longer harmless phrase that contains a term, such as an identifier (only that phrase is hidden; the term elsewhere still blocks) |

Text is read as UTF-8; when a file is not UTF-8 it is read as Shift_JIS (CP932) and EUC-JP; UTF-16 with a byte order mark is read too. Matching runs after NFKC normalisation (full-width and half-width forms become one) and with invisible characters removed, case-insensitively. Terms that start or end with an ASCII letter or digit match whole words, also inside camelCase and snake_case identifiers; terms that start or end with katakana do not match inside a longer katakana word; other terms match anywhere.

The hooks fail closed: with no terms, or when every `sources.txt` pattern matches nothing (a moved or unmounted folder), the commit stops.

| Variable (`=1` only) | Effect |
|---|---|
| `PUBLIC_GUARD_SKIP` | bypass the hooks for one command — only with the owner's consent |
| `PUBLIC_GUARD_ALLOW_EMPTY` | allow running without terms (secrets only) |
| `PUBLIC_GUARD_NO_GITLEAKS` | do not run gitleaks |
| `PUBLIC_GUARD_CONFIG_DIR` | another folder for the term lists (any path) |

## What it cannot stop

- Text written outside git: pull request titles and bodies, issues, comments, edits in the GitHub web UI
- The contents of binary, Office and PDF files, and UTF-16 text without a byte order mark (their names are checked)
- A name glued to digits or written in capitals inside an identifier (`acme2024`, `ACMECLIENT`)
- A name split across lines or written with other characters inside it (`Ac-me`)
- Commits made with hooks bypassed (`--no-verify` or `PUBLIC_GUARD_SKIP=1`) that are pushed from a repository without the hooks

## When a hook stops you

Write generic text instead of the name; a generic word belongs in `allowlist.txt`.

## Tests

```bash
python3 -B -m unittest discover -s git-hooks/tests
```
