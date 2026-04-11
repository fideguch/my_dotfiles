#!/usr/bin/env node
'use strict';

/**
 * gatekeeper Pre-Edit Guard Hook (PreToolUse: Edit|Write)
 *
 * Blocks src/ file edits when HG-1 (RESEARCH BEFORE CODE) has not passed.
 * Ensures designs/ and Figma are read before any implementation code is written.
 *
 * Session file: {GATEKEEPER_SESSION_DIR}/.gatekeeper/session.json
 * Fallback: process.cwd()/.gatekeeper/session.json
 * Exit codes: 0 = allow, 2 = block
 */

const fs = require('fs');
const path = require('path');

const SESSION_DIR = process.env.GATEKEEPER_SESSION_DIR || process.cwd();
const SESSION_FILE = path.join(SESSION_DIR, '.gatekeeper', 'session.json');

try {
  // No session file → not a gatekeeper session, allow
  if (!fs.existsSync(SESSION_FILE)) {
    process.exit(0);
  }

  const session = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));

  // Session version check
  if (!session.version || !session.gates) {
    process.exit(0);
  }

  const toolInput = JSON.parse(process.env.TOOL_INPUT || '{}');
  const filePath = toolInput.file_path || '';

  // Only guard src/ edits (implementation code)
  // Allow: designs/, tests/, e2e/, public/, supabase/, .claude/, checklists/, etc.
  if (!filePath.includes('/src/')) {
    process.exit(0);
  }

  // HG-1 check
  const hg1 = session.gates.hg1;

  if (hg1.status === 'PASS' || hg1.status === 'skipped') {
    // HG-1 passed or skipped (standalone bug fix mode)
    process.exit(0);
  }

  if (hg1.status === 'pending') {
    // BLOCK: HG-1 not yet completed
    process.stderr.write(
      `\n[gatekeeper HG-1 BLOCK] src/ edit blocked: designs/ and Figma not yet verified.\n` +
      `Action required:\n` +
      `  1. Read relevant designs/ files (grep -rl "keyword" designs/)\n` +
      `  2. Call Figma get_design_context for the target screen\n` +
      `  3. Update session: gates.hg1.status -> "PASS"\n` +
      `Blocked file: ${filePath}\n`
    );
    process.exit(2);
  }

  // Any other status → allow
  process.exit(0);

} catch (err) {
  // On error, don't block the user
  if (err.code !== 'ENOENT') {
    process.stderr.write(`[gatekeeper] Hook error (non-blocking): ${err.message}\n`);
  }
  process.exit(0);
}
