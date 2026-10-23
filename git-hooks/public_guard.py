#!/usr/bin/env python3
"""public-guard: stop client names and secrets from reaching a public repository.

  public_guard.py staged                       pre-commit: added lines and names of the staged files
  public_guard.py message <file>               commit-msg: the commit message
  public_guard.py pre-push <remote> <url>      pre-push: ref names and every commit about to be pushed
                                               (added lines, file names, commit messages); refs on stdin
  public_guard.py files                        audit: every tracked text file
  public_guard.py count                        print how many terms are loaded (never the terms)

Terms live outside the repository, in $PUBLIC_GUARD_CONFIG_DIR (default ~/.config/public-guard):
  denylist.txt   one term per line (`#` starts a comment)
  sources.txt    glob patterns of folders; each matching folder's name is a term
                 (a leading `NNN-` is stripped; `NN-` folders and everything below them are skipped)
  allowlist.txt  a term to ignore (a generic word that is also a folder name), or a longer harmless
                 phrase that contains a term (an identifier, for example): only that phrase is hidden
Matching (after NFKC, without invisible characters): case-insensitive. ASCII terms match whole words,
also inside camelCase and snake_case identifiers; terms starting/ending with katakana do not match inside
a longer katakana word; other terms match anywhere.
Fails closed: no terms, or sources that match no folder, stop the commit (PUBLIC_GUARD_ALLOW_EMPTY=1 checks
secrets only). Secrets: gitleaks when installed (PUBLIC_GUARD_NO_GITLEAKS=1 turns it off).
PUBLIC_GUARD_SKIP=1 bypasses everything. Exit: 0 clean, 1 findings, 2 usage, configuration or git error.
"""
from __future__ import annotations

import bisect
import glob
import os
import re
import shutil
import subprocess
import sys
import unicodedata
from typing import Iterable, Iterator, List, NamedTuple, Optional, Sequence, Tuple

ZERO_SHA = "0" * 40
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
CONFIG_DIR = os.environ.get("PUBLIC_GUARD_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".config", "public-guard")
NUMBERED_PREFIX = re.compile(r"^\d{3}-")
NUMBERED_FOLDER = re.compile(r"^\d{2}-")
KATAKANA = "ァ-ヺー-ヿㇰ-ㇿ"  # without ゠ (U+30A0) and the middle dot ・ (U+30FB)
INVISIBLE = re.compile("[­᠎​-‏‪-‮⁠-⁤﻿]")
HUNK = re.compile(r"^@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
SCISSORS = re.compile(r"^. -+ >8 -+$")
MAX_REPORT = 50
SNIFF_BYTES = 8000
GIT = ["git", "-c", "core.quotePath=false", "-c", "diff.noprefix=false", "-c", "diff.mnemonicPrefix=false",
       "-c", "color.ui=false", "-c", "diff.renames=true"]
DIFF_OPTIONS = ["--no-color", "--no-ext-diff", "--no-textconv", "--text", "-U0", "-M",
                "--src-prefix=a/", "--dst-prefix=b/"]


class Finding(NamedTuple):
    where: str
    term: str


class Change(NamedTuple):
    path: str      # path after the change
    old_path: str  # path before a rename ('' otherwise)
    mode: str      # mode after the change
    blob: str      # blob id after the change


class Patterns(NamedTuple):
    quick: Optional["re.Pattern[str]"]     # every term, casefolded, no boundaries: finds candidate lines fast
    combined: Optional["re.Pattern[str]"]  # every term with its boundaries: the real check
    names: dict  # group name -> term
    hidden: List["re.Pattern[str]"]


def flag(name: str) -> bool:
    return os.environ.get(name) == "1"


def normalize(text: str) -> str:
    return INVISIBLE.sub("", unicodedata.normalize("NFKC", text))


# --- terms -------------------------------------------------------------------------------------------

def read_lines(name: str) -> List[str]:
    try:
        with open(os.path.join(CONFIG_DIR, name), encoding="utf-8-sig") as handle:
            lines = [normalize(line.split("#", 1)[0]).strip() for line in handle]
    except FileNotFoundError:
        return []
    return [line for line in lines if line]


def wildcard_parts(pattern: str, path: str) -> List[str]:
    """Path components that a wildcard of the pattern matched (the pattern's literal folders are left out)."""
    pattern_parts, path_parts = pattern.rstrip("/").split("/"), path.rstrip("/").split("/")
    if len(pattern_parts) != len(path_parts):
        return [path_parts[-1]]
    return [part for spec, part in zip(pattern_parts, path_parts) if glob.has_magic(spec)]


def source_terms(patterns: Iterable[str]) -> Tuple[List[str], List[str]]:
    """Names of the folders matching the patterns, and the patterns that matched no folder.
    A numbered folder (`01-fix`) and anything below it is skipped: those hold documents, not names."""
    terms, dead = [], []
    for pattern in patterns:
        expanded = os.path.expanduser(pattern)
        folders = [path for path in glob.glob(expanded) if os.path.isdir(path)]
        if not folders:
            dead.append(pattern)
        for path in folders:
            matched = [normalize(part) for part in wildcard_parts(expanded, path)]
            name = normalize(os.path.basename(path.rstrip("/")))
            if name.startswith(".") or any(NUMBERED_FOLDER.match(part) for part in matched):
                continue
            terms.append(NUMBERED_PREFIX.sub("", name))
    return terms, dead


def load_terms() -> Tuple[List[str], List[str], List[str], int]:
    """Terms to block, allowlisted phrases, sources that matched nothing, number of sources."""
    allowed = read_lines("allowlist.txt")
    allowed_keys = {phrase.casefold() for phrase in allowed}
    sources = read_lines("sources.txt")
    derived, dead = source_terms(sources)
    unique = {term.casefold(): term for term in read_lines("denylist.txt") + derived
              if term and term.casefold() not in allowed_keys}
    return sorted(unique.values(), key=len, reverse=True), allowed, dead, len(sources)


def edge(char: str, side: str) -> str:
    """Lookaround that makes a term stop at a word boundary on one side."""
    if char.isascii() and char.isalnum():
        if side == "left":  # not after a letter/digit, unless a camelCase hump starts here
            return "(?:(?<![A-Za-z0-9])|(?<=[a-z0-9])(?=[A-Z]))"
        return "(?:(?![A-Za-z0-9])|(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z]))"
    if re.match(f"[{KATAKANA}]", char):
        return f"(?<![{KATAKANA}])" if side == "left" else f"(?![{KATAKANA}])"
    return ""


def trie_regex(words: Sequence[str]) -> str:
    """One regex for many literal words, shaped as a trie (fast: no alternation of whole words)."""
    trie: dict = {}
    for word in words:
        node = trie
        for char in word:
            node = node.setdefault(char, {})
        node[""] = True

    def build(node: dict) -> str:
        branches = [re.escape(char) + build(child) for char, child in sorted(node.items()) if char]
        if not branches:
            return ""
        if len(branches) == 1 and "" not in node:
            return branches[0]
        return "(?:" + "|".join(branches) + ")" + ("?" if "" in node else "")

    return build(trie)


def compile_terms(terms: Sequence[str], allowed: Sequence[str]) -> Patterns:
    names, parts = {}, []
    for index, term in enumerate(terms):
        group = f"t{index}"
        names[group] = term
        parts.append(f"(?P<{group}>{edge(term[0], 'left')}(?i:{re.escape(term)}){edge(term[-1], 'right')})")
    combined = re.compile("|".join(parts)) if parts else None
    quick = re.compile(trie_regex([term.casefold() for term in terms])) if terms else None
    hidden = [re.compile(f"(?i:{re.escape(phrase)})") for phrase in sorted(allowed, key=len, reverse=True)]
    return Patterns(quick, combined, names, hidden)


def strict_terms(line: str, patterns: Patterns) -> List[str]:
    """Terms in one normalized line; a match that lies wholly inside an allowlisted phrase is not counted."""
    hidden = [(m.start(), m.end()) for regex in patterns.hidden for m in regex.finditer(line)]
    found: List[str] = []
    for match in patterns.combined.finditer(line):
        if any(start <= match.start() and match.end() <= end for start, end in hidden):
            continue
        term = patterns.names[match.lastgroup]
        if term not in found:
            found.append(term)
    return found


def scan_entries(entries: Sequence[Tuple[str, str]], patterns: Patterns) -> List[Finding]:
    """Findings in (where, line) pairs: one fast pass over all lines, the strict check on candidate lines only."""
    if patterns.quick is None or patterns.combined is None or not entries:
        return []
    lines = [normalize(text) for _, text in entries]
    folded = [line.casefold() for line in lines]
    starts, offset = [], 0
    for line in folded:
        starts.append(offset)
        offset += len(line) + 1
    candidates = {bisect.bisect_right(starts, m.start()) - 1 for m in patterns.quick.finditer("\n".join(folded))}
    return [Finding(entries[index][0], term) for index in sorted(candidates)
            for term in strict_terms(lines[index], patterns)]


def scan_text(where: str, text: str, patterns: Patterns) -> List[Finding]:
    return scan_entries([(where, text)], patterns)


def scan_lines(where: str, text: str, patterns: Patterns, first: int = 1) -> List[Finding]:
    entries = [(f"{where}:{number}", line) for number, line in enumerate(text.split("\n"), start=first)]
    return scan_entries(entries, patterns)


# --- git ---------------------------------------------------------------------------------------------

def run_git(*args: str, binary: bool = False):
    result = subprocess.run([*GIT, *args], capture_output=True)
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(message or f"git {' '.join(args)} failed")
    return result.stdout if binary else result.stdout.decode("utf-8", errors="replace")


def parse_raw(raw: str) -> List[Change]:
    """Entries of `git diff --raw -z` (renames carry two paths)."""
    parts, changes, index = raw.split("\0"), [], 0
    while index < len(parts) and parts[index].startswith(":"):
        meta = parts[index][1:].split(" ")
        status = meta[4]
        if status[0] in "RC":
            old, new, index = parts[index + 1], parts[index + 2], index + 3
        else:
            old, new, index = "", parts[index + 1], index + 2
        changes.append(Change(new, old if status[0] == "R" else "", meta[1], meta[3]))
    return changes


def added_lines(diff: str) -> Iterator[Tuple[int, str]]:
    """Added lines of a one-file `git diff -U0`: hunk bodies are read by their line counts, so a content
    line that looks like a header is still content."""
    lines, index = diff.split("\n"), 0
    while index < len(lines):
        hunk = HUNK.match(lines[index])
        index += 1
        if not hunk:
            continue
        old_left = int(hunk.group(1)) if hunk.group(1) is not None else 1
        number = int(hunk.group(2))
        new_left = int(hunk.group(3)) if hunk.group(3) is not None else 1
        while (old_left > 0 or new_left > 0) and index < len(lines):
            line, index = lines[index], index + 1
            if line.startswith("\\"):
                continue  # "\ No newline at end of file"
            if line.startswith("+"):
                yield number, line[1:]
                number, new_left = number + 1, new_left - 1
            elif line.startswith("-"):
                old_left -= 1
            else:
                old_left, new_left, number = old_left - 1, new_left - 1, number + 1


def blob_kind(data: bytes) -> str:
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return "utf16"
    return "binary" if b"\0" in data[:SNIFF_BYTES] else "text"


def change_findings(change: Change, base: Sequence[str], label: str, patterns: Patterns) -> List[Finding]:
    """Name and added content of one changed file; `base` selects the diff (staged or between commits)."""
    findings = scan_text(f"{label}{change.path} (file name)", change.path, patterns)
    if change.mode == "160000":
        return findings  # submodule
    data = run_git("cat-file", "blob", change.blob, binary=True)
    kind = blob_kind(data)
    if kind == "utf16":
        return findings + scan_lines(f"{label}{change.path}", data.decode("utf-16", errors="replace"), patterns)
    if kind == "binary":
        return findings
    paths = [f":(literal){path}" for path in (change.old_path, change.path) if path]
    diff = run_git("diff", *DIFF_OPTIONS, *base, "--", *paths)
    entries = [(f"{label}{change.path}:{number}", line) for number, line in added_lines(diff)]
    return findings + scan_entries(entries, patterns)


def diff_findings(base: Sequence[str], label: str, patterns: Patterns) -> List[Finding]:
    raw = run_git("diff", "--raw", "-z", "--no-abbrev", "-M", "--diff-filter=ACMRT", *base)
    findings: List[Finding] = []
    for change in parse_raw(raw):
        findings += change_findings(change, base, label, patterns)
    return findings


def comment_char() -> str:
    try:
        value = run_git("config", "--get", "core.commentChar").strip()
        return value if value and value != "auto" else "#"
    except RuntimeError:
        return "#"


def message_findings(text: str, where: str, patterns: Patterns, strip_comments: bool) -> List[Finding]:
    entries: List[Tuple[str, str]] = []
    marker = comment_char() if strip_comments else None
    for number, line in enumerate(text.split("\n"), start=1):
        if marker and SCISSORS.match(line):
            break  # below the scissors line git drops everything
        if marker and line.startswith(marker):
            continue
        entries.append((f"{where}:{number}", line))
    return scan_entries(entries, patterns)


def pushed(stdin_lines: Iterable[str], remote: str, patterns: Patterns) -> Tuple[List[str], List[str], List[Finding]]:
    """Commits about to be pushed, their ranges (for gitleaks), and findings in the ref names."""
    commits: dict = {}
    ranges: List[str] = []
    findings: List[Finding] = []
    for line in stdin_lines:
        parts = line.split()
        if len(parts) != 4 or parts[1] == ZERO_SHA:
            continue  # malformed, or a deletion
        local_ref, local, remote_ref, remote_sha = parts
        for ref in dict.fromkeys((local_ref, remote_ref)):
            findings += scan_text(f"{ref} (ref name)", ref, patterns)
        if remote_sha == ZERO_SHA:
            spec = [local, "--not", f"--remotes={remote}"]
        else:
            try:
                run_git("cat-file", "-e", f"{remote_sha}^{{commit}}")
            except RuntimeError:
                raise RuntimeError(f"the remote commit {remote_sha[:7]} is not known here — run `git fetch` first")
            spec = [f"{remote_sha}..{local}"]
        ranges.append(" ".join(spec))
        for sha in run_git("rev-list", *spec).split():
            commits.setdefault(sha, None)
    return list(commits), ranges, findings


def commit_findings(commits: Sequence[str], patterns: Patterns) -> List[Finding]:
    findings: List[Finding] = []
    for sha in commits:
        short = sha[:7]
        message = run_git("log", "-1", "--format=%B", sha)
        findings += message_findings(message, f"commit {short} (commit message)", patterns, strip_comments=False)
        parents = run_git("log", "-1", "--format=%P", sha).split()
        base = [parents[0] if parents else EMPTY_TREE, sha]  # merges: what the merge brings in
        findings += diff_findings(base, f"commit {short} ", patterns)
    return findings


def file_findings(patterns: Patterns) -> List[Finding]:
    findings: List[Finding] = []
    for path in run_git("ls-files", "-z").split("\0"):
        if not path:
            continue
        findings += scan_text(f"{path} (file name)", path, patterns)
        if not os.path.isfile(path) or os.path.islink(path):
            continue
        with open(path, "rb") as handle:
            data = handle.read()
        kind = blob_kind(data)
        if kind == "utf16":
            findings += scan_lines(path, data.decode("utf-16", errors="replace"), patterns)
        elif kind == "text":
            findings += scan_lines(path, data.decode("utf-8", errors="replace"), patterns)
    return findings


# --- secrets and output ------------------------------------------------------------------------------

def gitleaks_ok(args: Sequence[str]) -> bool:
    if flag("PUBLIC_GUARD_NO_GITLEAKS"):
        return True
    if not shutil.which("gitleaks"):
        print("public-guard: gitleaks is not installed — secrets were not scanned", file=sys.stderr)
        return True
    result = subprocess.run(["gitleaks", "git", "--redact", "--no-banner", *args, "."], capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout + result.stderr, file=sys.stderr)
        print("public-guard: gitleaks found a secret (values redacted above)", file=sys.stderr)
        return False
    return True


def report(findings: Sequence[Finding]) -> int:
    if not findings:
        return 0
    print("public-guard: this repository is public — client or internal names found:", file=sys.stderr)
    for finding in findings[:MAX_REPORT]:
        print(f"  {finding.where}: \"{finding.term}\"", file=sys.stderr)
    if len(findings) > MAX_REPORT:
        print(f"  … and {len(findings) - MAX_REPORT} more", file=sys.stderr)
    print("Write generic text instead. A generic word belongs in "
          f"{os.path.join(CONFIG_DIR, 'allowlist.txt')}. Bypass only with the owner's consent: PUBLIC_GUARD_SKIP=1",
          file=sys.stderr)
    return 1


def config_problem(terms: Sequence[str], dead: Sequence[str], source_count: int) -> Optional[str]:
    for pattern in dead:
        print(f"public-guard: sources.txt pattern matched no folder: {pattern}", file=sys.stderr)
    if flag("PUBLIC_GUARD_ALLOW_EMPTY"):
        return None
    if source_count and len(dead) == source_count:
        return "every sources.txt pattern matched no folder (moved or unmounted?)"
    if not terms:
        return f"no terms configured in {CONFIG_DIR}"
    return None


def run(mode: str, args: Sequence[str], patterns: Patterns) -> int:
    if mode == "staged":
        findings = diff_findings(["--cached"], "", patterns)
        return max(report(findings), 0 if gitleaks_ok(["--staged"]) else 1)
    if mode == "message":
        with open(args[0], encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        return report(message_findings(text, "commit message", patterns, strip_comments=True))
    if mode == "pre-push":
        commits, ranges, findings = pushed(sys.stdin.read().split("\n"), args[0] if args else "origin", patterns)
        secret_ok = all([gitleaks_ok(["--log-opts", spec]) for spec in ranges])
        return max(report(findings + commit_findings(commits, patterns)), 0 if secret_ok else 1)
    return report(file_findings(patterns))


def main(argv: Sequence[str]) -> int:
    if flag("PUBLIC_GUARD_SKIP"):
        print("public-guard: skipped (PUBLIC_GUARD_SKIP=1)", file=sys.stderr)
        return 0
    if not argv or argv[0] not in ("staged", "message", "pre-push", "files", "count") or \
            (argv[0] == "message" and len(argv) < 2):
        print(__doc__, file=sys.stderr)
        return 2
    terms, allowed, dead, source_count = load_terms()
    if argv[0] == "count":
        print(f"{len(terms)} terms loaded from {CONFIG_DIR}")
        return 0
    problem = config_problem(terms, dead, source_count)
    if problem:
        print(f"public-guard: {problem} — names cannot be checked. Fix the lists (git-hooks/README.md), or set "
              "PUBLIC_GUARD_ALLOW_EMPTY=1 to check secrets only", file=sys.stderr)
        return 2
    try:
        return run(argv[0], argv[1:], compile_terms(terms, allowed))
    except (RuntimeError, OSError) as err:
        print(f"public-guard: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
