#!/usr/bin/env node
'use strict';

/**
 * PM Pipeline Guard Hook (PreToolUse: Write)
 *
 * Blocks creation of plan.md or tasks.md when designs/ directory
 * does not exist or requirements quality score is below 70.
 *
 * This enforces the pipeline order:
 *   /requirements_designer → designs/ → /speckit-bridge → plan → tasks → implement
 */

const fs = require("fs");
const path = require("path");

// Claude Code delivers the tool payload on stdin as JSON ({tool_name, tool_input, ...}),
// NOT via a TOOL_INPUT env var (Claude Code never sets one). Read stdin, fail-open on error.
function readToolInput() {
  try {
    const raw = fs.readFileSync(0, "utf8");
    if (!raw) return {};
    return JSON.parse(raw).tool_input || {};
  } catch {
    return {};
  }
}

// The Discord bridge session is a conversational companion, not a PM pipeline
// context — plan.md writes there are meeting notes, not implementation plans.
if (process.env.CLAUDE_BRIDGE === "1") {
  process.exit(0);
}

const TOOL_INPUT = readToolInput();
const filePath = TOOL_INPUT.file_path || "";

// Only guard plan.md and tasks.md writes
const guardedFiles = ["plan.md", "tasks.md"];
const basename = path.basename(filePath);

if (!guardedFiles.includes(basename)) {
  // Not a guarded file, allow
  process.exit(0);
}

// Allow spec-kit output (specs/) and agent-state files (.fable/, .claude/) — these
// are not PM pipeline plans, so the designs/ gate must not block them.
if (
  filePath.includes("/specs/") ||
  filePath.includes("/.fable/") ||
  filePath.includes("/.claude/")
) {
  process.exit(0);
}

// Check if designs/ directory exists relative to the file being written
const fileDir = path.dirname(filePath);
const projectRoot = findProjectRoot(fileDir);

if (!projectRoot) {
  // Can't determine project root, allow (don't block on edge cases)
  process.exit(0);
}

const designsDir = path.join(projectRoot, "designs");

if (!fs.existsSync(designsDir)) {
  const result = {
    decision: "block",
    reason:
      "designs/ directory not found. Run /requirements_designer first to create requirements before writing implementation plans.\n\nPipeline order: /requirements_designer → /speckit-bridge → plan → tasks → implement",
  };
  console.log(JSON.stringify(result));
  process.exit(0);
}

// Check if functional_requirements.md exists with at least one FR
const frPath = path.join(designsDir, "functional_requirements.md");

if (!fs.existsSync(frPath)) {
  const result = {
    decision: "block",
    reason:
      "designs/functional_requirements.md not found. Complete Phase 2 of /requirements_designer (functional requirements extraction) before creating plans.",
  };
  console.log(JSON.stringify(result));
  process.exit(0);
}

let frContent;
try {
  frContent = fs.readFileSync(frPath, "utf8");
} catch {
  // Can't read the requirements file (e.g. EACCES) — fail-open, never block the write.
  process.exit(0);
}

if (!frContent.includes("FR-001")) {
  const result = {
    decision: "block",
    reason:
      "No functional requirements (FR-001) found in designs/functional_requirements.md. Complete requirements extraction before creating plans.",
  };
  console.log(JSON.stringify(result));
  process.exit(0);
}

// All checks passed, allow
process.exit(0);

/**
 * Walk up from dir to find a directory that looks like a project root
 * (contains .git, package.json, or designs/)
 */
function findProjectRoot(dir) {
  let current = dir;
  const root = path.parse(current).root;

  while (current !== root) {
    if (
      fs.existsSync(path.join(current, ".git")) ||
      fs.existsSync(path.join(current, "package.json")) ||
      fs.existsSync(path.join(current, "designs"))
    ) {
      return current;
    }
    current = path.dirname(current);
  }
  return null;
}
