# forge_ace Anti-Patterns Reference Card

13 structural failure patterns detected across all forge_ace agents.
Each agent's Anti-Patterns section references this file for full definitions.

## Anti-Patterns (HARD-GATE — detect and act)

### 1. Spec-as-Done Illusion
Writing a spec/README and treating it as "implemented."
A spec file is NOT evidence of working code.
**Detection**: Agent report cites spec/doc as proof of implementation.
**Action**: Require Bash execution evidence showing the spec'd behavior actually works.

### 2. Phantom Addition Fallacy
Planning to "add" something that already exists.
**Detection**: Plan says "create" or "add" without first reading the target file.
**Action**: Read the file first. Prove absence before creation. Label steps CREATE/MODIFY.

### 3. Delegated Verification Deficit
Trusting subagent or tool reports without independent verification.
**Detection**: Agent cites another agent's claim as sole evidence.
**Action**: VP-1 — verify independently with Bash/Read/Grep. "They said PASS" ≠ evidence.

### 4. Delta Thinking Trap
Estimating quality as "+N points" instead of full rubric re-evaluation.
**Detection**: Score justification references deltas rather than absolute measurements.
**Action**: VP-2 — blind re-evaluation of ALL rubric items before viewing prior scores.

### 5. Stale Context Divergence
Using old line numbers, outdated memory records, or stale file state.
**Detection**: Agent references specific line numbers from earlier in the session.
**Action**: Re-read files before referencing. Use content anchors, not line numbers.

### 6. Spec-without-Implementation-Table
Creating a spec that references external components (CLI, cron, hook, API, DB migration,
env vars) without appending an Implementation Status table (✅/❌).
**Detection**: Spec file mentions external dependencies but no status table at bottom.
**Action**: Append `## Implementation Status` table. Any ❌ = "not implemented."

### 7. Precondition-as-Assumption
Test descriptions containing "(with X present)", "(assuming Y)", "(after Z)" —
hidden preconditions that are not independently tested.
**Detection**: Grep test descriptions for "(with", "(assuming", "(after" patterns.
**Action**: Extract each precondition as an independent test. Precondition FAIL → dependent tests SKIP (not PASS).

### 8. High-Risk-Implementation-Gap
Session-external work referenced without user confirmation. Claude's known weak spots:
- cron / launchd / systemd (session-external scheduling)
- SSH server configuration (may be unreachable)
- OAuth / browser auth flows (Claude cannot operate browsers)
- Production environment variables (.env.production)
- DNS / SSL certificates / CI-CD pipeline configuration
**Detection**: Task content matches above patterns.
**Action**: Output `⚠️ HIGH RISK PATTERN: [name]`. Do NOT proceed without user confirmation.

### 9. Disconnected-Bloodline
Code references external server/API/DB connections but reachability is not verified.
Markdown config ≠ live connection.
**Detection**: Code contains SSH/HTTP/DB/S3/MQ/WS connection patterns.
**Action**: Run reachability test (ssh/curl/aws CLI). Output = evidence. No output = no approval.
Guardian Phase 2.7 performs systematic detection and verification.

### 10. Deployment-Sync Blindness
Git-managed file and runtime file are at different paths; `git pull` alone does not
update the runtime copy. Symlinks, hooks scripts, env files, and settings copied
outside the repo are all targets.
**Detection**: Deploy script has `git pull` but no `cp`/`ln`/`scp`. Modified file's
git repo path differs from the runtime reference path. `diff <git_version> <runtime_version>` shows divergence.
**Action**: For every modified file, verify: git repo path = runtime reference path.
If different, confirm a sync mechanism exists (symlink, install script, deploy hook).
Run `diff` between git version and runtime version as evidence. No diff output = no approval.
Guardian Phase 2.7 includes Deployment-Sync verification alongside connectivity checks.

### 11. Spec-Layer Blindness (修正した気になる)
spec/prompt/config 修正を「修正完了」と扱い、振る舞いの検証なしで承認する。
AP#1 のメタレベル版: レビューチェーン全体が spec を構造的に評価し、
対象システムが実際にこの指示に従うかを検証しない。
**Detection**: 変更対象が .md prompt, SKILL.md, config YAML/JSON,
自然言語指示ドキュメント (Type B)。全エージェントが構造レビューのみで承認。
E2E 振る舞い証拠なし。
**Action**:
  1. Type A (実行可能コード) か Type B (spec/prompt/config) かを分類
  2. Type B → Reproduce-Before-Fix (修正前にバグの存在を実証)
  3. Type B → Delta Demonstration (before vs after の振る舞い差分を提示)
  4. Type B → Guardian が「構造レビューでは振る舞い準拠を検証不可」と明示フラグ
  5. Type B → 最終ゲートで E2E シナリオ証拠を要求（テスト PASS ではなく振る舞い変化）

### 12. Agent-Skip Rationalization (勝手にフロー縮小)
ユーザーが明示的に Tier を指定したのに、エージェントが「不要」と
自己判断してフローをスキップする。Tier 指定はユーザーの意思決定であり、
エージェント側で縮小してはならない。
**Detection**: Checkpoint Template の "確定 Tier" がユーザー指定と不一致。
または Checkpoint Template が未記入のまま agent dispatch 実行。
または "標準パイプラインからの逸脱" が YES で ユーザー未承認。
**Action**:
  1. Orchestrator は forge_ace Dispatch Checkpoint (SKILL.md) を必ず記入
  2. "確定 Tier" はユーザー指定がある場合そちらが優先（Classifier は advisory）
  3. "ユーザー確認: PENDING" を解決してから agent dispatch
  4. 逸脱がある場合はユーザーに選択肢を提示して承認を得る

### 13. Default-Permissive Trap (許可側デフォルトの罠)
未登録/未定義の入力に対するデフォルト挙動が **permissive (許可・成功・存在側)**
に倒れており、データ層の網羅漏れがアプリ層で検出されない。OWASP "Fail-Safe Defaults"
原則違反の構造パターン。型強制 (`bool("TBD") == True`) で truthy/falsy が潰れて
3 値以上の状態を 2 値に圧縮する亜種を含む。

**Real-world example (2026-04-30, ai-pokemen v0.3.1)**:
```python
def is_implemented(category, sid) -> bool:
    entry = impl.get(category, {}).get(sid)
    if entry is None:
        return True   # ← Default-Permissive
    return bool(entry.get("implemented", True))  # ← bool("TBD") == True で潰れる
```
データ層に登録漏れがあった `chienpao` (パオジアン) が True を返し、構築提案で
"Tier S 環境最強格" と誤評価された。Champions Reg M-A 規格外の可能性が高いポケモン。

**Detection**:
- 新規/変更された lookup・判定・gate 関数の **未登録/未定義入力時のデフォルト戻り値**
- `if entry is None: return True/proceed/grant/allow` 等のパターン
- `bool(value)` / `if value:` 等で多値ステータス (Pending/TBD/Unknown) が True 化
- whitelist 方式 vs blacklist 方式の選択根拠が文書化されていない
- 「未登録 = 暗黙的に安全」を仮定したコメント

**Action**:
  1. **Default surface 列挙**: 変更で追加/修正された全 gate 関数 (lookup/permission/feature flag/validation) のデフォルト戻り値を列挙
  2. **Permissive justification**: デフォルトが許可側 (True/grant/proceed) ならば
     「なぜ拒否側 (False/deny/TBD) より安全か」を 1 段落で justify。
     justify 不能なら **fail-safe (拒否側) に変更**
  3. **Truthy collapse check**: 多値ステータスを返す関数で `bool(x)` / `if x:` の
     呼び出し箇所を grep。罠があれば 3 値返却 + 厳密判定 (`is True`) に書き換え
  4. **Unregistered-input E2E**: 「データ層に登録されていない入力を投入した時、
     gate がどう振る舞うか」のテストを 1 件以上追加 (registration drift 検知)
  5. **Whitelist vs Blacklist 文書化**: data/README.md 等にどちらの方式かと
     その理由 (UX vs Security トレードオフ) を明記

**Severity**: HIGH (誤判定が実害につながる場合) / MEDIUM (内部ツール) /
LOW (ログ・統計のみ)。今回事例は MEDIUM (個人スキル・実害無し)。
