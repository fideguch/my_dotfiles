#!/usr/bin/env node
'use strict';

/**
 * forge_ace Dispatch Guard Hook (PreToolUse: Agent)
 *
 * Enforces the agent dispatch sequence in forge_ace sessions:
 *   Writer → Guardian → Overseer → PM-Admin → Designer
 *
 * Reads state from /tmp/.forge-ace-session.json and blocks
 * out-of-order agent dispatches.
 */

const fs = require('fs');
const path = require('path');

const SESSION_FILE = '/tmp/.forge-ace-session.json';

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

  const toolInput = JSON.parse(process.env.TOOL_INPUT || '{}');
  const description = toolInput.description || '';

  // Read session state
  let session;
  try {
    session = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
  } catch {
    // Corrupt/unreadable session file → fail-open
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
  const result = {
    decision: 'block',
    reason: `forge_ace: ${matchedGate.name} agent requires state [${matchedGate.requiredStates[0]}] but current state is [${currentState}]. Dispatch sequence: Writer→Guardian→Overseer→PM-Admin→Designer`,
  };
  console.log(JSON.stringify(result));
  process.exit(0);
} catch {
  // Any unexpected error → fail-open
  process.exit(0);
}
