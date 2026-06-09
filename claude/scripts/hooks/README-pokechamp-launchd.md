# Pokemon Champions skill — 定期更新 launchd セットアップガイド

## 概要

`/pokechamp` スキルが依存する 3 つのデータ層を、OS レベル (launchd) で**必ず**定期更新する。
Claude Code の SessionStart hook が**死活監視**を担い、launchd ジョブが落ちたら自動復元する。

| 層 | トリガー | 役割 | 対象スクリプト | 出力先 |
|----|---------|------|---------------|--------|
| 1. **OS 定期実行** | launchd | champs / pokechamdb 使用率取得 (6h) | `fetch_champs_usage.py` | `cache/champs_usage/YYYY-MM-DD.json` |
| 2. **OS 定期実行** | launchd | YT 字幕取得 (毎日 06:00 JST) | `fetch_yt_transcripts.py` | `cache/yt_transcripts/YYYY-MM-DD/` |
| 3. **OS 定期実行** | launchd | niche 妨害技採用率 (毎日 05:00 JST) | `fetch_all_niche.sh` (11技 loop) | `cache/niche_users/YYYY-MM-DD/<move>.json` |
| 4. **死活監視** | Claude Code SessionStart hook | 3 ジョブが activeか確認、欠落なら自動復元 | `pokechamp-ensure-schedule.sh` | `~/.claude/logs/pokechamp-ensure-schedule.log` |

## なぜ launchd / cron でなく Hook で完結させないか

- Claude Code SessionStart hook は **CLI 起動時しか発火しない**。CLI が立ち上がっていない時間 (深夜含む) は沈黙 = 鮮度命層 TTL (6h) を確実に守れない。
- launchd は再起動を跨いでも生存し、JST 時刻指定で日次実行が可能。
- Hook は **launchd の死活監視**として位置付け、OS 層が壊れても Claude Code 起動時に自動修復される。

## 有効化 (初回のみ)

```bash
# 1. plist が ~/Library/LaunchAgents/ にあるか確認
ls ~/Library/LaunchAgents/com.fideguch.pokechamp-*.plist

# 2. setup スクリプトで bootstrap (冪等、何度実行してもOK)
bash /Users/fumito_ideguchi/ai-pokemen/scripts/setup_scheduled_updates.sh

# 3. SessionStart hook が settings.json に登録されているか確認
python3 -c "import json; s=json.load(open('/Users/fumito_ideguchi/.claude/settings.json')); \
  print([h for hs in s['hooks']['SessionStart'] for h in hs['hooks'] if 'pokechamp' in h.get('command','')])"
```

## 動作確認

```bash
# 登録確認 (3 ジョブが表示されればOK)
launchctl list | grep -E "fideguch\.pokechamp"

# 次回実行時刻を見る
launchctl print gui/$(id -u)/com.fideguch.pokechamp-fetch-yt | grep -E "next_run|state"

# 手動キック (即時実行、TTL を無視したい時は --force を付けて手動コマンド)
launchctl kickstart -k gui/$(id -u)/com.fideguch.pokechamp-fetch-usage
launchctl kickstart -k gui/$(id -u)/com.fideguch.pokechamp-fetch-yt
launchctl kickstart -k gui/$(id -u)/com.fideguch.pokechamp-fetch-niche

# ログ tail
tail -f ~/.claude/logs/pokechamp-fetch-usage.out.log
tail -f ~/.claude/logs/pokechamp-fetch-yt.out.log
tail -f ~/.claude/logs/pokechamp-fetch-niche.out.log
tail -f ~/.claude/logs/pokechamp-ensure-schedule.log
```

## 無効化 / 一時停止

```bash
# 一時停止 (再起動で復活)
launchctl bootout gui/$(id -u)/com.fideguch.pokechamp-fetch-usage
launchctl bootout gui/$(id -u)/com.fideguch.pokechamp-fetch-yt
launchctl bootout gui/$(id -u)/com.fideguch.pokechamp-fetch-niche

# 完全無効化 (plist 自体を削除)
rm ~/Library/LaunchAgents/com.fideguch.pokechamp-*.plist

# SessionStart hook も外す → ~/.claude/settings.json を編集して
# 'pokechamp-ensure-schedule.sh' エントリを削除
```

## トラブルシュート

### `python3: command not found` がログに出る

launchd は対話シェルの PATH を継承しない。plist の `EnvironmentVariables.PATH` で
`/Users/fumito_ideguchi/.pyenv/shims:/opt/homebrew/bin:...` を指定済み。
それでも出る場合:

```bash
# pyenv shim の実体を確認
ls -la /Users/fumito_ideguchi/.pyenv/shims/python3
# 必要なら plist のフルパス /Users/fumito_ideguchi/.pyenv/shims/python3 を直接書き換え
```

### `cache/champs_usage/YYYY-MM-DD.json` が増えない

```bash
# TTL hit で skip されているだけかもしれない (6h)
ls -la /Users/fumito_ideguchi/ai-pokemen/cache/champs_usage/_meta.json
cat /Users/fumito_ideguchi/ai-pokemen/cache/champs_usage/_meta.json

# 強制 refetch
cd /Users/fumito_ideguchi/ai-pokemen && python3 scripts/fetch_champs_usage.py --force
```

### YT 字幕が取れない

```bash
# yt-dlp が入っているか
which yt-dlp || brew install yt-dlp

# RSS が降りているか
curl -s "https://www.youtube.com/feeds/videos.xml?channel_id=UCmnZL4tFRl4sm-uJOxTLHmg" | head -50
```

### niche 11 技のうち一部だけ FAIL する

`cache/niche_users/YYYY-MM-DD/` に成功分のみ残る (failure isolation 設計)。
失敗した技だけ手動 refetch:

```bash
python3 /Users/fumito_ideguchi/ai-pokemen/scripts/fetch_niche_users.py トリック
```

### SessionStart hook が「missing jobs」と毎回ログを吐く

setup スクリプトの bootstrap が継続的にコケている。手動実行して原因特定:

```bash
bash -x /Users/fumito_ideguchi/ai-pokemen/scripts/setup_scheduled_updates.sh
```
