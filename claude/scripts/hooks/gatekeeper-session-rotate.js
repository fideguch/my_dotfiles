#!/usr/bin/env node
'use strict';

/**
 * gatekeeper Session Rotate Hook (Stop: *)
 *
 * When a gatekeeper session is complete (final_status !== null):
 * 1. Move session.json to history/{timestamp}.json
 * 2. Keep latest 3 in history, delete older
 * 3. Cap hypothesis_tracker.failed at 10 entries (drop oldest)
 *
 * Session file: {GATEKEEPER_SESSION_DIR}/.gatekeeper/session.json
 * History dir:  {GATEKEEPER_SESSION_DIR}/.gatekeeper/history/
 * Fallback: process.cwd()/.gatekeeper/session.json
 * Exit codes: 0 always (Stop hooks should never block)
 */

const fs = require('fs');
const path = require('path');

const SESSION_DIR = process.env.GATEKEEPER_SESSION_DIR || process.cwd();
const GATEKEEPER_DIR = path.join(SESSION_DIR, '.gatekeeper');
const SESSION_FILE = path.join(GATEKEEPER_DIR, 'session.json');
const HISTORY_DIR = path.join(GATEKEEPER_DIR, 'history');
const MAX_HISTORY = 3;
const MAX_FAILED_HYPOTHESES = 10;

try {
  // No session file → nothing to rotate
  if (!fs.existsSync(SESSION_FILE)) {
    process.exit(0);
  }

  const session = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));

  if (!session.version || !session.gates) {
    process.exit(0);
  }

  // Cap hypothesis_tracker.failed at MAX_FAILED_HYPOTHESES (drop oldest)
  if (session.hypothesis_tracker && Array.isArray(session.hypothesis_tracker.failed)) {
    if (session.hypothesis_tracker.failed.length > MAX_FAILED_HYPOTHESES) {
      session.hypothesis_tracker.failed = session.hypothesis_tracker.failed.slice(
        session.hypothesis_tracker.failed.length - MAX_FAILED_HYPOTHESES
      );
      // Write back the capped version
      fs.writeFileSync(SESSION_FILE, JSON.stringify(session, null, 2), 'utf8');
    }
  }

  // Only rotate if session is complete
  if (session.final_status === null || session.final_status === undefined) {
    process.exit(0);
  }

  // Create history directory if needed
  if (!fs.existsSync(HISTORY_DIR)) {
    fs.mkdirSync(HISTORY_DIR, { recursive: true });
  }

  // Generate timestamp filename (ISO with colons replaced for filesystem safety)
  const timestamp = new Date().toISOString().replace(/:/g, '-');
  const historyFile = path.join(HISTORY_DIR, `${timestamp}.json`);

  // Move session.json to history
  fs.copyFileSync(SESSION_FILE, historyFile);
  fs.unlinkSync(SESSION_FILE);

  // Prune history: keep latest MAX_HISTORY, delete older
  const historyFiles = fs.readdirSync(HISTORY_DIR)
    .filter(f => f.endsWith('.json'))
    .sort(); // ISO timestamps sort lexicographically

  if (historyFiles.length > MAX_HISTORY) {
    const toDelete = historyFiles.slice(0, historyFiles.length - MAX_HISTORY);
    for (const file of toDelete) {
      fs.unlinkSync(path.join(HISTORY_DIR, file));
    }
  }

  process.stderr.write(
    `[gatekeeper] Session rotated to history/${timestamp}.json (${historyFiles.length > MAX_HISTORY ? historyFiles.length - MAX_HISTORY : 0} old sessions pruned)\n`
  );

} catch (err) {
  if (err.code !== 'ENOENT') {
    process.stderr.write(`[gatekeeper] Rotate hook error (non-blocking): ${err.message}\n`);
  }
}

// Always exit 0 — Stop hooks should never block
process.exit(0);
