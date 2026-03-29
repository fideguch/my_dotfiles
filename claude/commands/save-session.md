---
description: |
  Save current session state to a dated file in ~/.claude/sessions/ so work can be resumed in a future session with full context.
  JP triggers: "セッションを保存", "引き継ぎ", "保存して終了",
  "ここまでを記録", "記録して", "セッションをまとめて", "ハンドオフ",
  "次のセッションに引き継いで", "ここまでの会話を記録",
  "セッションを保存して終了", "このセッションを保存"
  EN triggers: "save session", "hand off", "handoff",
  "wrap up session", "save and quit", "save this session"
---

# Save Session Command

Capture everything that happened in this session — what was built, what worked, what failed, what's left — and write it to a dated file so the next session can pick up exactly where this one left off.

## When to Use

- End of a work session before closing Claude Code
- Before hitting context limits (run this first, then start a fresh session)
- After solving a complex problem you want to remember
- Any time you need to hand off context to a future session
- When a major milestone was reached (all tests pass, feature complete, PR merged)

## Data Gathering Protocol

<HARD-GATE>
Before writing ANY session content, execute ALL of the following steps.
Writing from conversation memory alone is PROHIBITED.

1. Run `git status` in the current working directory
2. Run `git diff --stat` to capture changed files
3. Run `git log --oneline -5` to capture recent commits
4. Read `~/.claude/projects/-Users-fumito-ideguchi/memory/MEMORY.md`
5. Scan the conversation for: decisions, failed approaches, errors, discoveries
6. Note: current working directory, active plan files, running services

If not in a git repository, skip steps 1-3 and note "not a git repo" in the Environment section.
</HARD-GATE>

## Process

### Step 1: Gather context (via HARD-GATE above)

Execute every step in the Data Gathering Protocol. Do NOT proceed until all steps are done.

### Step 2: Create the sessions folder if it doesn't exist

Create the canonical sessions folder in the user's Claude home directory:

```bash
mkdir -p ~/.claude/sessions
```

### Step 3: Write the session file

Create `~/.claude/sessions/YYYY-MM-DD-<short-id>-session.tmp`, using today's actual date and a short-id that satisfies the following rules:

- Allowed characters: lowercase `a-z`, digits `0-9`, hyphens `-`
- Minimum length: 8 characters
- No uppercase letters, no underscores, no spaces

Valid examples: `abc123de`, `a1b2c3d4`, `frontend-worktree-1`
Invalid examples: `ABC123de` (uppercase), `short` (under 8 chars), `test_id1` (underscore)

Full valid filename example: `2024-01-15-abc123de-session.tmp`

The legacy filename `YYYY-MM-DD-session.tmp` is still valid, but new session files should prefer the short-id form to avoid same-day collisions.

### Step 4: Populate the file with all sections below

Write every section honestly. Do not skip sections — write "Nothing yet" or "N/A" if a section genuinely has no content. An incomplete file is worse than an honest empty section.

### Step 5: Show the file to the user

After writing, display the full contents and ask:

```
Session saved to [actual resolved path to the session file]

Does this look accurate? Anything to correct or add before we close?
```

Wait for confirmation. Make edits if requested.

---

## Session File Format

```markdown
# Session: YYYY-MM-DD

**Started:** [approximate time if known]
**Last Updated:** [current time]
**Project:** [project name or path]
**Topic:** [one-line summary of what this session was about]

---

## What We Are Building

[1-3 paragraphs describing the feature, bug fix, or task. Include enough
context that someone with zero memory of this session can understand the goal.
Include: what it does, why it's needed, how it fits into the larger system.]

---

## What WORKED (with evidence)

[List only things that are confirmed working. For each item include WHY you
know it works — test passed, ran in browser, Postman returned 200, etc.
Without evidence, move it to "Not Tried Yet" instead.]

- **[thing that works]** — confirmed by: [specific evidence]
- **[thing that works]** — confirmed by: [specific evidence]

If nothing is confirmed working yet: "Nothing confirmed working yet — all approaches still in progress or untested."

---

## What Did NOT Work (and why)

[This is the most important section. List every approach tried that failed.
For each failure write the EXACT reason so the next session doesn't retry it.
Be specific: "threw X error because Y" is useful. "didn't work" is not.]

- **[approach tried]** — failed because: [exact reason / error message]
- **[approach tried]** — failed because: [exact reason / error message]

If nothing failed: "No failed approaches yet."

---

## What Has NOT Been Tried Yet

[Approaches that seem promising but haven't been attempted. Ideas from the
conversation. Alternative solutions worth exploring. Be specific enough that
the next session knows exactly what to try.]

- [approach / idea]
- [approach / idea]

If nothing is queued: "No specific untried approaches identified."

---

## Current State of Files

[Every file touched this session. Be precise about what state each file is in.]

| File              | Status         | Notes                      |
| ----------------- | -------------- | -------------------------- |
| `path/to/file.ts` | ✅ Complete    | [what it does]             |
| `path/to/file.ts` | 🔄 In Progress | [what's done, what's left] |
| `path/to/file.ts` | ❌ Broken      | [what's wrong]             |
| `path/to/file.ts` | 🗒️ Not Started | [planned but not touched]  |

If no files were touched: "No files modified this session."

---

## Decisions Made

[Architecture choices, tradeoffs accepted, approaches chosen and why.
These prevent the next session from relitigating settled decisions.]

- **[decision]** — reason: [why this was chosen over alternatives]

If no significant decisions: "No major decisions made this session."

---

## Blockers & Open Questions

[Anything unresolved that the next session needs to address or investigate.
Questions that came up but weren't answered. External dependencies waiting on.]

- [blocker / open question]

If none: "No active blockers."

---

## Exact Next Step

[If known: The single most important thing to do when resuming. Be precise
enough that resuming requires zero thinking about where to start.]

[If not known: "Next step not determined — review 'What Has NOT Been Tried Yet'
and 'Blockers' sections to decide on direction before starting."]

---

## Environment & Setup Notes

[Only fill this if relevant — commands needed to run the project, env vars
required, services that need to be running, etc. Skip if standard setup.]

[If none: omit this section entirely.]
```

---

## Example Output

```markdown
# Session: 2024-01-15

**Started:** ~2pm
**Last Updated:** 5:30pm
**Project:** my-app
**Topic:** Building JWT authentication with httpOnly cookies

---

## What We Are Building

User authentication system for the Next.js app. Users register with email/password,
receive a JWT stored in an httpOnly cookie (not localStorage), and protected routes
check for a valid token via middleware. The goal is session persistence across browser
refreshes without exposing the token to JavaScript.

---

## What WORKED (with evidence)

- **`/api/auth/register` endpoint** — confirmed by: Postman POST returns 200 with user
  object, row visible in Supabase dashboard, bcrypt hash stored correctly
- **JWT generation in `lib/auth.ts`** — confirmed by: unit test passes
  (`npm test -- auth.test.ts`), decoded token at jwt.io shows correct payload
- **Password hashing** — confirmed by: `bcrypt.compare()` returns true in test

---

## What Did NOT Work (and why)

- **Next-Auth library** — failed because: conflicts with our custom Prisma adapter,
  threw "Cannot use adapter with credentials provider in this configuration" on every
  request. Not worth debugging — too opinionated for our setup.
- **Storing JWT in localStorage** — failed because: SSR renders happen before
  localStorage is available, caused React hydration mismatch error on every page load.
  This approach is fundamentally incompatible with Next.js SSR.

---

## What Has NOT Been Tried Yet

- Store JWT as httpOnly cookie in the login route response (most likely solution)
- Use `cookies()` from `next/headers` to read token in server components
- Write middleware.ts to protect routes by checking cookie existence

---

## Current State of Files

| File                             | Status         | Notes                                           |
| -------------------------------- | -------------- | ----------------------------------------------- |
| `app/api/auth/register/route.ts` | ✅ Complete    | Works, tested                                   |
| `app/api/auth/login/route.ts`    | 🔄 In Progress | Token generates but not setting cookie yet      |
| `lib/auth.ts`                    | ✅ Complete    | JWT helpers, all tested                         |
| `middleware.ts`                  | 🗒️ Not Started | Route protection, needs cookie read logic first |
| `app/login/page.tsx`             | 🗒️ Not Started | UI not started                                  |

---

## Decisions Made

- **httpOnly cookie over localStorage** — reason: prevents XSS token theft, works with SSR
- **Custom auth over Next-Auth** — reason: Next-Auth conflicts with our Prisma setup, not worth the fight

---

## Blockers & Open Questions

- Does `cookies().set()` work inside a Route Handler or only in Server Actions? Need to verify.

---

## Exact Next Step

In `app/api/auth/login/route.ts`, after generating the JWT, set it as an httpOnly
cookie using `cookies().set('token', jwt, { httpOnly: true, secure: true, sameSite: 'strict' })`.
Then test with Postman — the response should include a `Set-Cookie` header.
```

---

## Quality Gates

<HARD-GATE>
The session file MUST satisfy ALL of the following before showing to the user:

1. All sections from the template are present (use "N/A" for genuinely empty ones)
2. "What Did NOT Work" section contains specific error messages, not vague descriptions
3. "Current State of Files" uses actual `git status` / `git diff` output, not guesses
4. "Exact Next Step" is actionable without reading the rest of the document
5. All file paths are absolute or relative to the project root
6. No secrets, tokens, or passwords in any section
</HARD-GATE>

## Post-Save Actions

After the session file passes the Quality Gates and user confirms:

1. **Update MEMORY.md** (if the session involved significant work):
   - Check `~/.claude/projects/-Users-fumito-ideguchi/memory/MEMORY.md`
   - If a `## Handoff` section exists, add or update an entry:
     `- [Topic](../sessions/YYYY-MM-DD-shortid-session.tmp) — one-line status`
   - If the session produced decisions or discoveries worth persisting beyond handoff,
     save them as appropriate memory types (project, feedback, etc.)

2. **bochi integration** (if `~/.claude/bochi-data/context-seeds/` directory exists):
   - Save a context-seed as `~/.claude/bochi-data/context-seeds/[YYYY-MM-DD]-session-[topic].md`
   - Include: topic summary, key decisions, next-session intent (plain markdown, no frontmatter)

## Anti-Patterns

| Pattern | Why it fails |
|---------|-------------|
| Writing state without running git status | Inaccurate state propagates to next session |
| Skipping "What Did NOT Work" | Next session repeats dead ends |
| Vague next step ("continue the work") | Zero context for next session |
| Including secrets or tokens | Security risk persisted in session files |
| Summarizing instead of being specific | "Fixed some bugs" vs "Fixed NPE in auth.ts:42 caused by null user.email" |

## Notes

- Each session gets its own file — never append to a previous session's file
- The "What Did NOT Work" section is the most critical — future sessions will blindly retry failed approaches without it
- If the user asks to save mid-session (not just at the end), save what's known so far and mark in-progress items clearly
- The file is meant to be read by Claude at the start of the next session via `/resume-session`
- Use the canonical global session store: `~/.claude/sessions/`
- Prefer the short-id filename form (`YYYY-MM-DD-<short-id>-session.tmp`) for any new session file
