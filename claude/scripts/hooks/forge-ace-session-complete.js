#!/usr/bin/env node
'use strict';

/**
 * forge_ace Session Complete Hook (Stop)
 *
 * Fires after EVERY response. Acts only when the run is COMPLETE, or when an incomplete run has had
 * no activity for FORGE_ACE_STALE_HOURS (default 24): keeps a copy of the state (run_dir/state-final.json
 * or state-stale.json, else the local fallback folder), then appends the outcome to the JSONL log and
 * removes the state file. A run whose state could not be copied is left untouched (no outcome line either).
 * The state may hold client details: the fallback folder is local only (not the synced bochi-data).
 *
 * Environment (tests use these so they never touch a live run or the real log):
 *   FORGE_ACE_SESSION_FILE   state file (default /tmp/.forge-ace-session.json)
 *   FORGE_ACE_OUTCOMES_DIR   outcome folder (default ~/.claude/bochi-data/forge-ace-outcomes)
 *   FORGE_ACE_FALLBACK_DIR   state copies without a usable run_dir (default ~/.claude/forge-ace/unarchived)
 *   FORGE_ACE_STALE_HOURS    idle hours before an incomplete run is cleaned up (default 24)
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const SESSION_FILE = process.env.FORGE_ACE_SESSION_FILE || '/tmp/.forge-ace-session.json';
const OUTCOMES_DIR = process.env.FORGE_ACE_OUTCOMES_DIR
  || path.join(process.env.HOME || os.homedir(), '.claude', 'bochi-data', 'forge-ace-outcomes');
const OUTCOMES_FILE = path.join(OUTCOMES_DIR, 'outcomes.jsonl');
const FALLBACK_DIR = process.env.FORGE_ACE_FALLBACK_DIR || path.join(os.homedir(), '.claude', 'forge-ace', 'unarchived');
const STALE_HOURS = Number(process.env.FORGE_ACE_STALE_HOURS) > 0 ? Number(process.env.FORGE_ACE_STALE_HOURS) : 24;
const STALE_MS = STALE_HOURS * 60 * 60 * 1000;
const FUTURE_SLACK_MS = 5 * 60 * 1000; // dates further in the future are typos, not activity

function warn(message) {
  process.stderr.write(`WARNING: ${message}\n`);
}

function fileMtimeMs() {
  try {
    return fs.statSync(SESSION_FILE).mtimeMs;
  } catch {
    return NaN;
  }
}

// Last activity of a run: the newest of the file's mtime, `updated` and `created` (future dates ignored).
// A run that started long ago but is still being updated is not stale.
function lastActivityMs(session) {
  const limit = Date.now() + FUTURE_SLACK_MS;
  const fields = [session.created, session.updated]
    .map((v) => (typeof v === 'string' || typeof v === 'number' ? new Date(v).getTime() : NaN));
  const times = [...fields, fileMtimeMs()].filter((t) => Number.isFinite(t) && t <= limit);
  return times.length ? Math.max(...times) : Date.now();
}

// run_dir must be an absolute path to a directory; `~` is expanded. Anything else is not trusted.
function resolveRunDir(runDir) {
  if (typeof runDir !== 'string' || runDir === '') return null;
  const expanded = runDir === '~' || runDir.startsWith('~/') ? path.join(os.homedir(), runDir.slice(1)) : runDir;
  if (!path.isAbsolute(expanded)) {
    warn(`forge_ace run_dir is not an absolute path: ${runDir}`);
    return null;
  }
  try {
    if (fs.statSync(expanded).isDirectory()) return expanded;
  } catch { /* falls through */ }
  warn(`forge_ace run_dir is not a directory: ${runDir}`);
  return null;
}

// Write a temp file next to the target and rename it over the target: a symlink planted at the
// target is replaced, never followed.
function writeAtomic(target, text) {
  const tmp = `${target}.tmp-${process.pid}`;
  fs.writeFileSync(tmp, text, { encoding: 'utf8', flag: 'wx' });
  try {
    fs.renameSync(tmp, target);
  } catch (err) {
    try { fs.unlinkSync(tmp); } catch { /* ignore */ }
    throw err;
  }
}

// Keep a copy of the state before the state file goes away. Returns false when no copy could be made.
function saveState(session, name) {
  const text = JSON.stringify(session, null, 1) + '\n';
  const runDir = resolveRunDir(session.run_dir);
  if (runDir) {
    try {
      writeAtomic(path.join(runDir, name), text);
      return true;
    } catch (err) {
      warn(`could not copy forge_ace state into run_dir: ${err.message}`);
    }
  }
  try {
    fs.mkdirSync(FALLBACK_DIR, { recursive: true });
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    writeAtomic(path.join(FALLBACK_DIR, `state-${stamp}.json`), text);
    return true;
  } catch (err) {
    warn(`could not keep forge_ace state, leaving ${SESSION_FILE} in place: ${err.message}`);
    return false;
  }
}

function appendOutcome(session, isComplete) {
  const outcome = {
    date: new Date().toISOString(),
    tier: session.tier || 'Standard',
    type: session.type || 'A',
    state: session.state || 'UNKNOWN',
    agents: session.agents || {},
    completed: isComplete,
  };
  try {
    fs.mkdirSync(OUTCOMES_DIR, { recursive: true });
    fs.appendFileSync(OUTCOMES_FILE, JSON.stringify(outcome) + '\n', 'utf8');
  } catch (err) {
    warn(`Could not write forge_ace outcome: ${err.message}`);
  }
}

// Empty, half-written or non-object state (a writer may be replacing it right now): keep it while it is
// recent; after STALE_HOURS move it aside under a new name (earlier evidence is never overwritten).
function moveAsideIfStale() {
  const mtime = fileMtimeMs();
  if (!Number.isFinite(mtime) || Date.now() - mtime < STALE_MS) return;
  let target = `${SESSION_FILE}.corrupt-${Date.now()}`;
  if (fs.existsSync(target)) target = `${target}-${process.pid}`;
  try {
    fs.renameSync(SESSION_FILE, target);
  } catch { /* ignore */ }
}

function main() {
  if (!fs.existsSync(SESSION_FILE)) return;

  let session;
  try {
    session = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf8'));
  } catch {
    moveAsideIfStale();
    return;
  }
  if (!session || typeof session !== 'object' || Array.isArray(session)) {
    moveAsideIfStale();
    return;
  }

  const currentState = session.state || 'UNKNOWN';
  const isComplete = currentState === 'COMPLETE';
  if (!isComplete) {
    const idleMs = Date.now() - lastActivityMs(session);
    if (idleMs < STALE_MS) return; // still in progress
    warn(`forge_ace session stale and incomplete (state: ${currentState}, idle: ${Math.round(idleMs / 60000)}min)`);
  }

  // Copy first: when nothing could be saved, leave the run alone (and do not log it again on every Stop).
  const needsCopy = Boolean(session.run_dir) || !isComplete;
  if (needsCopy && !saveState(session, isComplete ? 'state-final.json' : 'state-stale.json')) return;
  appendOutcome(session, isComplete);
  try {
    fs.unlinkSync(SESSION_FILE);
  } catch { /* ignore */ }
}

try {
  main();
} catch {
  // Unexpected error → fail-open: never block, never delete
}
process.exit(0);
