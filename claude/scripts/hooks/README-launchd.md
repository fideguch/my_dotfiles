# bochi S3 Hook 改善 — launchd セットアップガイド

## 概要

bochi の S3 同期は 3 層で構成されています:

| 層 | トリガー | 役割 | 対象スクリプト |
|----|---------|------|---------------|
| 1. リアルタイム | Claude Code PostToolUse hook (Write/Edit) | 即時 push | `bochi-s3-push.sh` |
| 2. セーフティネット | launchd (10 分間隔) | bash redirect 等 hook を経由しない書き込みを救済 | `bochi-s3-safety-push.sh` |
| 3. ヘルスチェック | launchd (毎週月曜 09:00 JST) | Lightsail 側で round-trip テスト | `bochi-s3-healthcheck.sh` (SSH wrapper) |

## 改善内容 (2026-04-30)

1. **High**: bash redirect (`cat > file`, heredoc) は PostToolUse hook を発火させないため、ローカルだけ更新されて S3 反映が漏れる問題を、launchd 10 分間隔の safety-push で構造的に解消
2. **Medium**: `bochi-s3-push.sh` の silent failure (AWS 認証エラー / network timeout) をログ捕捉、直近 1 時間で 3 回以上失敗した場合のみ macOS 通知を発火 (1 時間クールダウン)
3. **Low**: 既存 round-trip テスト `~/.claude/skills/bochi/tests/s3-sync-test.sh` を週次で自動実行 (SSH 経由)、失敗時のみ通知

## 有効化

```bash
launchctl load -w ~/Library/LaunchAgents/com.fideguch.bochi-safety-push.plist
launchctl load -w ~/Library/LaunchAgents/com.fideguch.bochi-healthcheck.plist
```

## 動作確認

```bash
# 登録確認 (両方が表示されればOK)
launchctl list | grep -E "fideguch\.bochi"

# 次回実行時刻 (Mon 09:00 が NextRunDate に出る)
launchctl list -x com.fideguch.bochi-healthcheck

# 手動キック (10 分待たずに即実行)
launchctl kickstart -k gui/$(id -u)/com.fideguch.bochi-safety-push
launchctl kickstart -k gui/$(id -u)/com.fideguch.bochi-healthcheck

# ログ tail
tail -f ~/.claude/logs/bochi-s3-push.log         # 失敗時のみ追記される
tail -f ~/.claude/logs/bochi-healthcheck.log     # 週次実行のたびに追記
tail -f ~/.claude/logs/bochi-safety-push.err.log # 10 分間隔の stderr
```

## 無効化

```bash
launchctl unload -w ~/Library/LaunchAgents/com.fideguch.bochi-safety-push.plist
launchctl unload -w ~/Library/LaunchAgents/com.fideguch.bochi-healthcheck.plist
```

## トラブルシュート

### `aws: command not found` がログに出る

launchd は対話シェルの `$PATH` を継承しないため、plist の `EnvironmentVariables.PATH` で `/opt/homebrew/bin:...` を指定済み。それでも出る場合:
- `which aws` が `/opt/homebrew/bin/aws` 以外を返していないか確認
- 必要なら plist の PATH を編集 → `launchctl unload -w ... && launchctl load -w ...`

### healthcheck が `Permission denied (publickey)` で失敗する

launchd は `ssh-agent` の SSH_AUTH_SOCK を継承しないため、passphrase 付き鍵だと失敗する。解決策:

```bash
# Keychain integration を有効化 (一度だけ)
ssh-add --apple-use-keychain ~/.ssh/<lightsail_key>

# ~/.ssh/config に Lightsail 専用エントリを追加 (Host alias で IP 変更にも対応しやすい)
Host bochi-lightsail
  HostName 54.249.49.69
  User ubuntu
  IdentityFile ~/.ssh/<lightsail_key>
  UseKeychain yes
  AddKeysToAgent yes
  IdentitiesOnly yes
```

その後 `bochi-s3-healthcheck.sh` の `LIGHTSAIL_HOST` を `bochi-lightsail` に変更可能 (現状は `ubuntu@54.249.49.69` ハードコード)。

### AWS 認証期限切れ (SSO セッション切れ等) の通知が鳴った

最も発生しやすい failure mode。ログには `expired token` / `Unable to locate credentials` 等が出る。

```bash
# 現在の認証状態確認
aws sts get-caller-identity --region ap-northeast-1

# SSO 利用時の再ログイン
aws sso login --profile <profile_name>

# IAM 鍵直接利用時の確認
echo "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" | head -c 20

# 通知クールダウンをリセット (再認証後すぐに通知が欲しい場合)
rm -f /tmp/bochi-s3-notify-last
```

### push.sh ログが肥大化

10MB を超えると自動で `.log.1.gz` に gzip rotate される。手動確認:

```bash
ls -la ~/.claude/logs/
du -sh ~/.claude/logs/
```

`*.out.log` / `*.err.log` (launchd 直接出力) はローテーションされないため、容量に応じて手動 truncate を推奨:

```bash
: > ~/.claude/logs/bochi-safety-push.out.log
: > ~/.claude/logs/bochi-safety-push.err.log
```

### 通知が出すぎる / 出ない

push.sh は「直近 1 時間で 3 回以上失敗 + 前回通知から 1 時間経過」で通知発火。クールダウンを手動リセット:

```bash
rm -f /tmp/bochi-s3-notify-last
```

## 依存関係

```
[Claude Code Write/Edit]
        │
        ▼
~/.claude/settings.json (PostToolUse matcher)
        │
        ▼
bochi-s3-push.sh ──▶ aws s3 sync ──▶ S3 ──▶ Lightsail bochi-data
        │ (失敗時)
        ▼
~/.claude/logs/bochi-s3-push.log
        │ (3+ failures/h)
        ▼
osascript display notification

────────────────────────────────────────────

[launchd 10 分間隔]
        │
        ▼
bochi-s3-safety-push.sh ──▶ find -newer marker ──▶ aws s3 sync (差分のみ)

────────────────────────────────────────────

[launchd 月曜 09:00 JST]
        │
        ▼
bochi-s3-healthcheck.sh ──▶ ssh ubuntu@Lightsail ──▶ s3-sync-test.sh (round-trip)
        │
        ▼
~/.claude/logs/bochi-healthcheck.log
        │ (失敗時)
        ▼
osascript display notification
```

## ファイル一覧

| パス | 種別 |
|------|------|
| `~/.claude/scripts/hooks/bochi-s3-push.sh` | 既存 hook、本改善で MODIFY (失敗ログ + 通知) |
| `~/.claude/scripts/hooks/bochi-s3-safety-push.sh` | 既存スクリプト、変更なし (launchd で起動) |
| `~/.claude/scripts/hooks/bochi-s3-healthcheck.sh` | 新規、SSH 経由で Lightsail テスト実行 |
| `~/Library/LaunchAgents/com.fideguch.bochi-safety-push.plist` | 新規、StartInterval 600 秒 |
| `~/Library/LaunchAgents/com.fideguch.bochi-healthcheck.plist` | 新規、月曜 09:00 JST |
| `~/.claude/logs/` | 新規ディレクトリ、全ログ集約 |
| `~/.claude/skills/bochi/tests/s3-sync-test.sh` | bochi スキル配下、READ ONLY (本改善で参照のみ) |
