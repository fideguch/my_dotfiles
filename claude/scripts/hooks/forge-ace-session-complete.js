#!/usr/bin/env node
'use strict';

/**
 * forge_ace Session Complete Hook (Stop)
 *
 * On session stop:
 * - Warns if forge_ace session is incomplete
 * - Saves outcome to JSONL log
 * - Cleans up the /tmp session file
 */

const fs = require('fs');
const path = require('path');

const SESSION_FILE = '/tmp/.forge-ace-session.json';
const OUTCOMES_DIR = path.join(
  process.env.HOME || '/tmp',
  '.claude',
  'bochi-data',
  'forge-ace-outcomes'
);
const OUTCOMES_FILE = path.join(OUTCOMES_DIR, 'outcomes.jsonl');

try {
  // No session file → nothing to do
  if (!fs.existsSync(SESSION_FILE)) {
    process.exit(0);
  }

  let session;
  try {
    session = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
  } catch {
    // Corrupt file → clean up and exit
    try { fs.unlinkSync(SESSION_FILE); } catch { /* ignore */ }
    process.exit(0);
  }

  const currentState = session.state || 'UNKNOWN';
  const isComplete = currentState === 'COMPLETE';

  // IMPORTANT: Stop hook fires after EVERY response, not just session end.
  // Only take action when state is COMPLETE.
  // For incomplete sessions, check if stale (>2 hours old) before cleanup.
  if (!isComplete) {
    const created = session.created ? new Date(session.created).getTime() : Date.now();
    const ageMs = Date.now() - created;
    const TWO_HOURS = 2 * 60 * 60 * 1000;

    if (ageMs < TWO_HOURS) {
      // Session still in progress → do nothing, don't delete
      process.exit(0);
    }

    // Stale session (>2h) → save as incomplete and clean up
    process.stderr.write(
      `WARNING: forge_ace session stale and incomplete (state: ${currentState}, age: ${Math.round(ageMs / 60000)}min)\n`
    );
  }

  // Build outcome record (COMPLETE or stale-incomplete)
  const outcome = {
    date: new Date().toISOString(),
    tier: session.tier || 'Standard',
    type: session.type || 'A',
    state: currentState,
    agents: session.agents || {},
    completed: isComplete,
  };

  // Ensure outcomes directory exists
  try {
    fs.mkdirSync(OUTCOMES_DIR, { recursive: true });
  } catch { /* ignore if exists */ }

  // Append outcome as JSONL
  try {
    fs.appendFileSync(OUTCOMES_FILE, JSON.stringify(outcome) + '\n', 'utf8');
  } catch (err) {
    process.stderr.write(`WARNING: Could not write forge_ace outcome: ${err.message}\n`);
  }

  // Clean up session file (only when COMPLETE or stale)
  try {
    fs.unlinkSync(SESSION_FILE);
  } catch { /* ignore */ }

  process.exit(0);
} catch {
  // Any unexpected error → fail-open (do NOT delete session file)
  process.exit(0);
}
