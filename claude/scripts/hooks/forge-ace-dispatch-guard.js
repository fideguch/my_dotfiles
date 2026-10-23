#!/usr/bin/env node
'use strict';

/**
 * forge_ace Dispatch Guard Hook (PreToolUse: Agent)
 *
 * Enforces the agent dispatch sequence in forge_ace sessions:
 *   Writer → Guardian → Overseer → PM-Admin → Designer
 *
 * Reads state from /tmp/.forge-ace-session.json (or FORGE_ACE_SESSION_FILE) and blocks
 * out-of-order agent dispatches.
 */

const fs = require('fs');
const path = require('path');

const SESSION_FILE = process.env.FORGE_ACE_SESSION_FILE || '/tmp/.forge-ace-session.json';
const STALE_HOURS = Number(process.env.FORGE_ACE_STALE_HOURS) > 0 ? Number(process.env.FORGE_ACE_STALE_HOURS) : 24;
const FUTURE_SLACK_MS = 5 * 60 * 1000;

// Same rule as the Stop hook: last activity = newest of mtime, `updated`, `created` (future dates ignored).
// A run idle for STALE_HOURS was abandoned and must not gate Agent calls in other work.
function lastActivityMs(session) {
  const limit = Date.now() + FUTURE_SLACK_MS;
  let mtime = NaN;
  try { mtime = fs.statSync(SESSION_FILE).mtimeMs; } catch { /* ignore */ }
  const fields = [session.created, session.updated]
    .map((v) => (typeof v === 'string' || typeof v === 'number' ? new Date(v).getTime() : NaN));
  const times = [...fields, mtime].filter((t) => Number.isFinite(t) && t <= limit);
  return times.length ? Math.max(...times) : Date.now();
}

// Claude Code delivers the tool payload on stdin as JSON ({tool_name, tool_input, ...}),
// NOT via a TOOL_INPUT env var (Claude Code never sets one). Read stdin, fail-open on error.
function readToolInput() {
  // Run by hand from a terminal: do not wait for input. (tty.isatty does not touch process.stdin, which would
  // switch fd 0 to non-blocking and make readFileSync(0) fail with EAGAIN before a slow writer has written.)
  if (require('tty').isatty(0)) return {};
  try {
    const raw = fs.readFileSync(0, 'utf8');
    if (!raw) return {};
    return JSON.parse(raw).tool_input || {};
  } catch {
    return {};
  }
}

// State prerequisites for each forge_ace agent
// Patterns are broad (no colon required) to prevent bypass via alternative phrasing.
// Order matters: more specific patterns first (PM-Admin before Admin).
// requiredStates includes later states (e.g., Writer allows GUARDIAN_DONE) intentionally:
// this permits rejection-recovery re-dispatch without resetting the full pipeline.
const AGENT_GATES = [
  { pattern: /Write change-set|Writer\b/i, requiredStates: ['USER_CONFIRMED', 'WRITER_DONE', 'GUARDIAN_DONE', 'OVERSEER_DONE', 'PM_ADMIN_DONE', 'DESIGNER_DONE', 'COMPLETE'], name: 'Writer' },
  { pattern: /Guardian\b/i, requiredStates: ['WRITER_DONE', 'GUARDIAN_DONE', 'OVERSEER_DONE', 'PM_ADMIN_DONE', 'DESIGNER_DONE', 'COMPLETE'], name: 'Guardian' },
  { pattern: /Overseer\b/i, requiredStates: ['GUARDIAN_DONE', 'OVERSEER_DONE', 'PM_ADMIN_DONE', 'DESIGNER_DONE', 'COMPLETE'], name: 'Overseer' },
  { pattern: /PM-Admin\b/i, requiredStates: ['OVERSEER_DONE', 'PM_ADMIN_DONE', 'DESIGNER_DONE', 'COMPLETE'], name: 'PM-Admin' },
  { pattern: /Designer\b/i, requiredStates: ['PM_ADMIN_DONE', 'DESIGNER_DONE', 'COMPLETE'], name: 'Designer' },
];

try {
  // No session file → not a forge_ace session, allow
  if (!fs.existsSync(SESSION_FILE)) {
    process.exit(0);
  }

  const toolInput = readToolInput();
  const description = toolInput.description || '';

  // Read session state
  let session;
  try {
    session = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
  } catch {
    // Corrupt/unreadable session file → fail-open
    process.exit(0);
  }

  if (!session || typeof session !== 'object' || Array.isArray(session)) {
    process.exit(0);
  }
  if (Date.now() - lastActivityMs(session) >= STALE_HOURS * 60 * 60 * 1000) {
    // Abandoned run → no longer gates anything
    process.exit(0);
  }

  const currentState = session.state || 'UNKNOWN';

  // Session already complete → allow everything
  if (currentState === 'COMPLETE') {
    process.exit(0);
  }

  // Check if description matches any forge_ace agent pattern
  const matchedGate = AGENT_GATES.find((gate) => gate.pattern.test(description));

  if (!matchedGate) {
    // Not a forge_ace agent dispatch → allow
    process.exit(0);
  }

  // Check if current state meets the prerequisite
  if (matchedGate.requiredStates.includes(currentState)) {
    // Prerequisite met → allow
    process.exit(0);
  }

  // State prerequisite not met → block
  const runHint = typeof session.run_dir === 'string' && session.run_dir
    ? `${session.run_dir}/NEXT.md`
    : 'its run folder (NEXT.md)';
  const result = {
    decision: 'block',
    reason: `forge_ace: ${matchedGate.name} agent requires state [${matchedGate.requiredStates[0]}] but current state is [${currentState}]. Dispatch sequence: Writer→Guardian→Overseer→PM-Admin→Designer. To continue this run, follow ${runHint}. Only if the user confirms the run was abandoned, remove the state file ${SESSION_FILE} (default /tmp/.forge-ace-session.json).`,
  };
  console.log(JSON.stringify(result));
  process.exit(0);
} catch {
  // Any unexpected error → fail-open
  process.exit(0);
}
