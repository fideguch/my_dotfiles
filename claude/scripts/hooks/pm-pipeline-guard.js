#!/usr/bin/env node

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

const TOOL_INPUT = JSON.parse(process.env.TOOL_INPUT || "{}");
const filePath = TOOL_INPUT.file_path || "";

// Only guard plan.md and tasks.md writes
const guardedFiles = ["plan.md", "tasks.md"];
const basename = path.basename(filePath);

if (!guardedFiles.includes(basename)) {
  // Not a guarded file, allow
  process.exit(0);
}

// Check if we're in a specs/ directory (spec-kit output) — allow those
if (filePath.includes("/specs/")) {
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

const frContent = fs.readFileSync(frPath, "utf8");

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
