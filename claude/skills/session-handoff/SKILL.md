---
name: session-handoff
description: |
  Save and hand off session context for seamless continuation.
  JP triggers: "セッションを保存", "引き継ぎ", "保存して終了",
  "ここまでを記録", "記録して", "セッションをまとめて", "ハンドオフ",
  "次のセッションに引き継いで", "ここまでの会話を記録",
  "セッションを保存して終了", "このセッションを保存"
  EN triggers: "save session", "hand off", "handoff",
  "wrap up session", "save and quit", "save this session"
  Also: /session-handoff
---

# Session Handoff

Structured session handoff for seamless continuation in the next session.

## Product Vision

AI session context is volatile. This skill captures the full session state
into a structured handoff document so the next session starts with zero
orientation overhead. Inspired by the 8-component handoff model, adapted
for Claude Code's memory system and git-centric workflow.

## Data Gathering Protocol

<HARD-GATE>
Before writing ANY handoff content, execute ALL of the following steps.
Writing from conversation memory alone is PROHIBITED.

1. Run `git status` in the current working directory
2. Run `git diff --stat` to capture changed files
3. Run `git log --oneline -5` to capture recent commits
4. Read `~/.claude/projects/-Users-fumito-ideguchi/memory/MEMORY.md`
5. Scan the conversation for: decisions, failed approaches, errors, discoveries
6. Note: current working directory, active plan files, running services

If not in a git repository, skip steps 1-3 and note "not a git repo" in Section 6.
</HARD-GATE>

## Output Template

Save to: `~/.claude/projects/-Users-fumito-ideguchi/memory/handoff_[topic_slug].md`

If a file with the same name exists, append `_[YYYYMMDD]` before `.md`.
If the dated name also exists, append `_[YYYYMMDD]_2` (increment suffix).

### File Format

````markdown
---
name: handoff_[topic_slug]
description: [one-line status summary with key metric if applicable]
type: project
---

# [Topic] — Session Handoff ([YYYY-MM-DD])

## 1. このセッションの目的 (Context)
Why this session existed. What problem was being solved.
One paragraph max.

## 2. 完了した作業 (Completed Work)
Evidence-backed list of what was accomplished:
- [task]: [file path / commit hash / command output as proof]

## 3. 決定事項 (Decided Items)
Decisions made during this session with rationale:
- [decision]: [why this was chosen over alternatives]

## 4. 未解決・ブロッカー (Unresolved Items)
What remains open. What is blocking progress.
- [item]: [why blocked, who/what needs to decide]

## 5. 失敗したアプローチ (Failed Approaches)
Approaches tried and abandoned. Prevents repetition in next session.
- [approach]: [why it failed, what was learned]

## 6. 現在の状態 (Current State)
- Working directory: [absolute path]
- Git branch: [branch name]
- Git status: [clean / dirty — list uncommitted files]
- Recent commits: [last 3-5 oneline]
- Infrastructure: [running services, deployed states, etc.]
- Key files modified: [list with absolute paths]

## 7. 次セッション用プロンプト (Next Session Prompt)

```
[Paste-ready, self-contained prompt for the next session.
Must include: what to do, what to read first, what to avoid.
Must be actionable without reading the rest of this document.]
```

## 8. 参照ファイル (Reference Files)
| File | Purpose | Priority |
|------|---------|----------|
| [absolute path] | [why to read] | MUST / SHOULD / MAY |
````

## Quality Gates

<HARD-GATE>
The handoff document MUST satisfy ALL of the following:

1. Sections 1, 2, 6, 7 are ALWAYS present (mandatory minimum of 4)
2. Section 5 is present if ANY approach was tried and abandoned
3. At least 1 of sections 3, 4, 8 is also present (total minimum: 5 sections)
4. Section 6 uses actual `git status` output, not guesses
5. Section 7 contains a code-fenced, paste-ready prompt
6. All file paths are absolute (starting with / or ~/)
7. No secrets, tokens, or passwords in any section
8. Topic slug is snake_case, English, max 40 characters
</HARD-GATE>

## Post-Save Actions

After saving the handoff file:

1. **Update MEMORY.md**: Add or update the entry under `## Handoff`
   - Format: `- [Title](filename.md) — one-line status`
   - If replacing an existing handoff for the same topic, update in-place

2. **bochi integration** (if `~/.claude/bochi-data/context-seeds/` directory exists):
   - Save a context-seed as `~/.claude/bochi-data/context-seeds/[YYYY-MM-DD]-handoff-[topic].md`
   - Include: topic summary, key decisions, next-session intent (plain markdown, no frontmatter)

3. **Notify user**: Print the saved file path and Section 7 prompt
   so the user can copy it immediately

## Anti-Patterns

| Pattern | Why it fails |
|---------|-------------|
| Writing current state without running git status | Inaccurate state propagates to next session |
| Skipping Failed Approaches | Next session repeats dead ends (proven by forge_ace v2.0 experience) |
| Vague next-session instructions ("continue the work") | Zero context for next session — defeats the purpose |
| Including secrets or tokens | Security risk persisted in memory files |
| One massive paragraph instead of 8 sections | Cannot scan quickly; next session wastes time parsing |
| Summarizing instead of being specific | "Fixed some bugs" vs "Fixed NPE in auth.ts:42 caused by null user.email" |

## Topic Slug Convention

Derive from the main theme of the session:
- `session_handoff_skill` (this session)
- `forge_ace_v2_pqg` (forge_ace Plan Quality Gate work)
- `bochi_realtime_sync` (bochi S3 sync project)
- `context_ghost_cleanup` (config drift fix session)

## When to Suggest Handoff

Proactively suggest `/session-handoff` when:
- The user says goodbye or ending phrases ("done for today", "wrap up", "thanks")
- Context window is approaching limits (strategic-compact territory)
- A major milestone was reached (all tests pass, feature complete, PR merged)
- The session has been running for an extended period with significant progress
