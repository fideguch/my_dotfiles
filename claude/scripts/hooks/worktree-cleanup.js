#!/usr/bin/env node
'use strict';

/**
 * SessionEnd hook: clean up orphaned agent worktrees.
 *
 * Scans `git worktree list --porcelain` for worktrees matching
 * `.claude/worktrees/agent-*`. Skips locked worktrees (active sessions).
 * Removes unlocked orphans and deletes their branches.
 *
 * Exports run() for in-process execution via run-with-flags.js.
 */

const { execSync, execFileSync } = require('child_process');
const path = require('path');

function findGitRoot(startDir) {
  try {
    return execSync('git rev-parse --show-toplevel', {
      cwd: startDir,
      encoding: 'utf8',
      timeout: 5000
    }).trim();
  } catch {
    return null;
  }
}

function listWorktrees(gitRoot) {
  try {
    const output = execSync('git worktree list --porcelain', {
      cwd: gitRoot,
      encoding: 'utf8',
      timeout: 5000
    });
    const entries = [];
    let current = {};
    for (const line of output.split('\n')) {
      if (line.startsWith('worktree ')) {
        if (current.path) entries.push(current);
        current = { path: line.slice('worktree '.length) };
      } else if (line.startsWith('branch ')) {
        current.branch = line.slice('branch '.length);
      } else if (line === 'locked' || line.startsWith('locked ')) {
        current.locked = true;
      } else if (line === '') {
        if (current.path) entries.push(current);
        current = {};
      }
    }
    if (current.path) entries.push(current);
    return entries;
  } catch {
    return [];
  }
}

function isAgentWorktree(gitRoot, entry) {
  const normalized = path.normalize(entry.path);
  const expected = path.join(gitRoot, '.claude', 'worktrees');
  return normalized.startsWith(expected + path.sep) &&
         path.basename(normalized).startsWith('agent-');
}

function removeWorktree(gitRoot, entry) {
  const removed = [];
  try {
    execFileSync('git', ['worktree', 'remove', '--force', entry.path], {
      cwd: gitRoot,
      encoding: 'utf8',
      timeout: 10000
    });
    removed.push(`worktree: ${path.basename(entry.path)}`);
  } catch (err) {
    process.stderr.write(`[worktree-cleanup] Failed to remove ${entry.path}: ${err.message}\n`);
    return removed;
  }

  if (entry.branch) {
    const branchName = entry.branch.replace('refs/heads/', '');
    try {
      execFileSync('git', ['branch', '-D', branchName], {
        cwd: gitRoot,
        encoding: 'utf8',
        timeout: 5000
      });
      removed.push(`branch: ${branchName}`);
    } catch (err) {
      process.stderr.write(`[worktree-cleanup] Could not delete branch ${branchName}: ${err.message}\n`);
    }
  }

  return removed;
}

function run(rawInput) {
  const cwd = process.cwd();
  const gitRoot = findGitRoot(cwd);
  if (!gitRoot) return rawInput || '';

  const worktrees = listWorktrees(gitRoot);
  const orphans = worktrees.filter(w => isAgentWorktree(gitRoot, w) && !w.locked);

  if (orphans.length === 0) return rawInput || '';

  const allRemoved = [];
  for (const orphan of orphans) {
    const removed = removeWorktree(gitRoot, orphan);
    allRemoved.push(...removed);
  }

  if (allRemoved.length > 0) {
    process.stderr.write(`[worktree-cleanup] Cleaned up: ${allRemoved.join(', ')}\n`);
  }

  return rawInput || '';
}

if (require.main === module) {
  const MAX_STDIN = 1024 * 1024;
  let raw = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => {
    if (raw.length < MAX_STDIN) {
      const remaining = MAX_STDIN - raw.length;
      raw += chunk.substring(0, remaining);
    }
  });
  process.stdin.on('end', () => {
    process.stdout.write(run(raw));
  });
}

module.exports = { run };
