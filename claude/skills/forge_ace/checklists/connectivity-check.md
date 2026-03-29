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
