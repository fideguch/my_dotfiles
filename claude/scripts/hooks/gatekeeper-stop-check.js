#!/usr/bin/env node
'use strict';

/**
 * gatekeeper Stop Check Hook (Stop: *)
 *
 * Warns when a gatekeeper session is incomplete (HG-5 verdict missing).
 * Does NOT block — only warns via stderr.
 *
 * Session file: {GATEKEEPER_SESSION_DIR}/.gatekeeper/session.json
 * Fallback: process.cwd()/.gatekeeper/session.json
 * Exit codes: 0 always (warn only, never block on Stop)
 */

const fs = require('fs');
const path = require('path');

const SESSION_DIR = process.env.GATEKEEPER_SESSION_DIR || process.cwd();
const SESSION_FILE = path.join(SESSION_DIR, '.gatekeeper', 'session.json');

try {
  // No session file → not a gatekeeper session
  if (!fs.existsSync(SESSION_FILE)) {
    process.exit(0);
  }

  const session = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));

  if (!session.version || !session.gates) {
    process.exit(0);
  }

  // Check if at least one gate has been activated
  const anyActive = Object.values(session.gates).some(
    g => g.status === 'PASS' || g.status === 'FAIL'
  );

  if (!anyActive) {
    // Session created but no gates activated yet — likely just started
    process.exit(0);
  }

  // Check HG-5 verdict
  const hg5 = session.gates.hg5;

  if (hg5.status === 'pending' || hg5.status === 'skipped') {
    process.stderr.write(
      `\n[gatekeeper HG-5 WARN] Session incomplete: verification verdict not reported.\n` +
      `Required: Report one of VERIFIED / BUILT / TESTED / NEEDS_USER\n` +
      `  - VERIFIED: Checked in browser with own eyes\n` +
      `  - BUILT: Code compiles (not browser-verified)\n` +
      `  - TESTED: Playwright/vitest passes (not browser-verified)\n` +
      `  - NEEDS_USER: Requires real device check\n`
    );
  }

  if (session.final_status === null && anyActive) {
    process.stderr.write(
      `[gatekeeper] Session final_status is null. Update ${SESSION_FILE} before closing.\n`
    );
  }

  // Check hypothesis tracker for unresolved debugging
  const tracker = session.hypothesis_tracker;
  if (tracker && tracker.attempt_count >= 2 && tracker.current !== null) {
    process.stderr.write(
      `[gatekeeper HG-4 WARN] Hypothesis "${tracker.current}" has ${tracker.attempt_count} attempts.\n` +
      `If 2+ failures: abandon this hypothesis and list 3 alternatives.\n`
    );
  }

} catch (err) {
  if (err.code !== 'ENOENT') {
    process.stderr.write(`[gatekeeper] Stop hook error (non-blocking): ${err.message}\n`);
  }
}

// Always exit 0 — Stop hooks should never block
process.exit(0);
