# Cross-Server Connectivity Check (Blood Vessel Verification)

> Guardian Phase 2.7 — extracted for reusability and readability.
> Code is "blood." Server connections are "blood vessels."
> Severed vessels = dead system regardless of code quality.

## [1] Connection Point Detection

Grep the changed code for these patterns:
- SSH/SCP: `ssh`, `scp`, `rsync`, `paramiko`, `ssh2`
- HTTP/API: `fetch`, `axios`, `curl`, `http.get`, `request`
- Database: `DATABASE_URL`, `pg_connect`, `mongoose.connect`, `prisma`, `knex`
- Cloud Storage: `aws s3`, `gsutil`, `@google-cloud/storage`, `S3Client`
- Message Queue: `amqplib`, `ioredis`, `bull`, `kafka`
- WebSocket: `ws://`, `wss://`, `new WebSocket`, `socket.io`

## [2] Reachability Verification

For each detected connection point, verify reachability:
- SSH: `ssh -o ConnectTimeout=5 -o BatchMode=yes user@host exit 2>/dev/null && echo OK`
- HTTP: `curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 URL`
- DB: Connection string syntax validation + env var existence check
- S3: `aws s3 ls s3://bucket --max-items 1 2>/dev/null && echo OK`

If unreachable:
- Own server → GUARDIAN_REJECTED (connection repair needed)
- External service → WARNING + "Unreachable — confirm with user"

## [3] Config File Integrity

- .env / config connection hostnames resolve or exist
- Environment-specific (dev/staging/prod) connections correctly separated
- Auth credential paths exist (do NOT read credential contents)

## [4] Integrate into Blast Radius Map

```
[changed file] --> [remote: host:port] (reachable / unreachable) [evidence: curl/ssh output]
```

## [5] Deployment-Sync Verification (Anti-Pattern #10)

For every modified file, check whether the git repo path equals the runtime reference path.

**Detection heuristics:**
- File is under a git repo (e.g., `~/my_dotfiles/claude/`) but referenced at runtime from a different path (e.g., `~/.claude/`)
- Deploy/install scripts have `git pull` but no corresponding `cp`/`ln`/`scp` for the changed file
- Symlinks exist but may be broken or stale (Claude Edit can replace symlinks with regular files)
- settings.json hook command paths differ from git repo file paths

**Verification steps:**
1. For each changed file, identify the runtime reference path:
   - Check for symlinks: `readlink -f <runtime_path>`
   - If no symlink, check install/deploy scripts for copy commands
2. Run `diff <git_repo_version> <runtime_version>`:
   - Identical → CLEAR
   - Divergent → DETECTED (sync mechanism broken or missing)
   - Runtime file missing → DETECTED (never deployed)
3. If symlink exists, verify it is not broken:
   - `[ -L <path> ] && [ -e <path> ] && echo VALID || echo BROKEN`

**Verdict:**
- All files: git path = runtime path (or valid symlink) → CLEAR
- Any divergence without sync mechanism → GUARDIAN_REJECTED
- Sync mechanism exists but not yet executed → WARNING + flag for user

**Integrate into Blast Radius Map:**
```
[changed file] --> [runtime: path] (synced / divergent / broken-symlink) [evidence: diff output]
```
