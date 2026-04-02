# Development Workflow

> This file extends [common/git-workflow.md](./git-workflow.md) with the full feature development process that happens before git operations.

The Feature Implementation Workflow describes the development pipeline: research, planning, TDD, code review, and then committing to git.

## Feature Implementation Workflow

0. **Research & Reuse** _(mandatory before any new implementation)_
   - **GitHub code search first:** Run `gh search repos` and `gh search code` to find existing implementations, templates, and patterns before writing anything new.
   - **Library docs second:** Use Context7 or primary vendor docs to confirm API behavior, package usage, and version-specific details before implementing.
   - **Exa only when the first two are insufficient:** Use Exa for broader web research or discovery after GitHub search and primary docs.
   - **Check package registries:** Search npm, PyPI, crates.io, and other registries before writing utility code. Prefer battle-tested libraries over hand-rolled solutions.
   - **Search for adaptable implementations:** Look for open-source projects that solve 80%+ of the problem and can be forked, ported, or wrapped.
   - Prefer adopting or porting a proven approach over writing net-new code when it meets the requirement.

1. **Plan First**
   - Use **planner** agent to create implementation plan
   - Generate planning docs before coding: PRD, architecture, system_design, tech_doc, task_list
   - Identify dependencies and risks
   - Break down into phases

2. **Implementation** _(route by change type)_

   **Existing code modification (DEFAULT):**
   - Use **forge_ace** skill when modifying existing code
   - Classify tier: Standard (code-only) or Full (UI present) — and type: A (code) or B (spec/prompt/config)
   - Standard: Writer → Guardian → Overseer(std) → PM-Admin(std)
   - Full: Writer → Guardian → Overseer(full) → PM-Admin(full) + Designer
   - All gates must pass before proceeding
   - See `~/.claude/skills/forge_ace/SKILL.md` (v4.0) for full protocol

   **New code only (greenfield):**
   - Use **tdd-guide** agent for TDD approach (RED → GREEN → IMPROVE)
   - Use **subagent-driven-development** for plan execution with independent tasks
   - Verify 80%+ coverage

   **Lightweight changes (1-2 files, no running system risk):**
   - Direct implementation with **code-reviewer** agent post-review is sufficient
   - Skip forge_ace to avoid overhead

3. **Code Review**
   - If forge_ace was used: Guardian + Overseer already reviewed — run final **code-reviewer** for holistic check
   - If not used: run **code-reviewer** agent immediately after writing code
   - Address CRITICAL and HIGH issues
   - Fix MEDIUM issues when possible

4. **Commit & Push**
   - Detailed commit messages
   - Follow conventional commits format
   - See [git-workflow.md](./git-workflow.md) for commit message format and PR process
