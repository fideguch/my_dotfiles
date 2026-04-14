# Claude Code 設定 (my_dotfiles/claude)

Claude Code の全グローバル設定を管理する dotfiles ディレクトリ。
`~/.claude/` にシンボリックリンクまたはコピーして使用する。

## ディレクトリ構成

```
claude/
├── CLAUDE.md              # グローバル指示（全プロジェクト共通）
├── settings.json          # Claude Code 本体設定
├── scripts/hooks/         # settings.json の hooks から呼び出される実行スクリプト群
├── rules/                 # コーディング規約（common/ + 言語別）
├── skills/                # スキル定義（SKILL.md ベース）
├── agents/                # サブエージェント定義（29種）
├── commands/              # スラッシュコマンド定義
└── templates/             # プロジェクトテンプレート
```

## 自作スキル

以下は自分で作成・カスタマイズしたスキル。ECC (Everything Claude Code) 同梱スキルとは別に管理。

### forge_ace — 5-Agent Quality Gate

| 項目 | 内容 |
|------|------|
| 起動 | `/forge_ace` |
| 目的 | コード修正の品質保証。Writer/Guardian/Overseer/PM-Admin/Designer の5エージェントが順序通りにレビュー |
| Tier | Standard（コードのみ）/ Full（UI あり） |
| 特徴 | セッション状態管理（`.forge-ace-session.json`）、dispatch-guard hook による順序強制、8軸品質評価 |
| hooks | `forge-ace-dispatch-guard.js`（PreToolUse）、`forge-ace-session-complete.js`（Stop） |
| テスト | `tests/test-dispatch-guard.sh`（14件）、`tests/test-state-machine.sh`（12件） |

### gatekeeper — 実装品質ゲート

| 項目 | 内容 |
|------|------|
| 起動 | `/gatekeeper` |
| 目的 | forge_ace が検出できない「実機で動くか」を保証。仕様確認・推測修正禁止・仮説固執防止・実機検証を強制 |
| 連携 | forge_ace Full とペアで使用（forge_ace の前後にゲートを配置） |
| HARD GATE | HG-1 仕様確認 / HG-2 品質踏襲 / HG-3 推測修正禁止 / HG-4 仮説固執防止 / HG-5 実機検証 |
| hooks | `gatekeeper-pre-edit-guard.js`（PreToolUse: src/ 編集ブロック）、`gatekeeper-stop-check.js`（Stop: 完了チェック） |
| 設計根拠 | RIPER-5 (2,590+)、trailofbits/skills (4,466+)、devin.cursorrules (5,962+)、CodeScene、Stripe/Airbnb harness、ACM認知バイアス研究 |
| テスト | `tests/test-gate-compliance.sh`（10件）、`tests/test-hooks.sh`（8件）、`test-scenarios/`（3シナリオ） |

### bochi — PM の外部脳

| 項目 | 内容 |
|------|------|
| 起動 | `/bochi`、「考えて」「まとめて」「整理して」等の日本語トリガー |
| 目的 | 思考・アイデア・コンテキスト追跡。S3同期で永続化 |
| hooks | `bochi-s3-pull.sh`、`bochi-s3-push.sh`、`bochi-feedback-capture.sh` |

### requirements_designer — 要件定義

| 項目 | 内容 |
|------|------|
| 起動 | `/requirements_designer` |
| 目的 | インタラクティブ Q&A で要件定義。designs/ に15ファイル生成 |
| 統合 | Figma MCP でデザインシステム・ワイヤーフレーム生成 |

### my_pm_tools — GitHub Projects PM

| 項目 | 内容 |
|------|------|
| 起動 | `/my_pm_tools` |
| 目的 | GitHub Projects V2 のPM支援。14ステータス・6ビュー・13ラベル構築、Sprint管理、分析 |

### speckit-bridge — 要件→仕様変換

| 項目 | 内容 |
|------|------|
| 起動 | `/speckit-bridge` |
| 目的 | requirements_designer の出力（designs/）を spec-kit 形式（spec.md）に変換 |

### figma-refine — Figma デザイン改善

| 項目 | 内容 |
|------|------|
| 起動 | `/figma-refine` |
| 目的 | Figma MCP + AIDesigner で designs/ のプロジェクトアイデンティティに沿ったデザイン改善 |

### pm-ad-analysis — 広告分析

| 項目 | 内容 |
|------|------|
| 起動 | `/pm-ad-analysis` |
| 目的 | Google Ads / Meta Ads / Apple Search Ads / TikTok Ads の横断分析 |

### pm-data-analysis — データ分析

| 項目 | 内容 |
|------|------|
| 起動 | `/pm-data-analysis` |
| 目的 | CSV/JSON/画像/MCP データソースからの GAFA 水準分析。バイアス検出・因果推論 |

### save-session / resume-session — セッション管理

| 項目 | 内容 |
|------|------|
| 起動 | `/save-session`、`/resume-session`、「引き継ぎ」「保存して終了」 |
| 目的 | セッション状態を `~/.claude/sessions/` に保存・復元。ハンドオフ用 |

### google-workspace — Google 連携

| 項目 | 内容 |
|------|------|
| 起動 | `/google-workspace`、「メール」「予定」「ファイル」 |
| 目的 | Gmail / Calendar / Drive / Sheets / Docs / Tasks の CLI 操作 |

## Hooks 体系

`settings.json` の `hooks` キーで定義。全セッションで自動実行される。

### PreToolUse hooks

| Hook | Matcher | 目的 |
|------|---------|------|
| block-no-verify | Bash | git --no-verify をブロック |
| auto-tmux-dev | Bash | dev サーバーを tmux で自動起動 |
| tmux-reminder | Bash | 長時間コマンドに tmux 推奨 |
| git-push-reminder | Bash | git push 前の確認 |
| doc-file-warning | Write | 不要なドキュメント作成を警告 |
| suggest-compact | Edit/Write | コンテキスト圧縮タイミング提案 |
| config-protection | Write/Edit | linter/formatter 設定の変更をブロック |
| pm-pipeline-guard | Write | designs/ なしで plan.md 作成をブロック |
| forge-ace-dispatch-guard | Agent | forge_ace エージェント順序強制 |
| **gatekeeper-pre-edit-guard** | Edit/Write | **HG-1 未通過で src/ 編集ブロック** |

### PostToolUse hooks

| Hook | Matcher | 目的 |
|------|---------|------|
| post-edit-format | Edit | JS/TS 自動フォーマット |
| post-edit-typecheck | Edit | TypeScript 型チェック |
| quality-gate | Edit/Write | 品質ゲートチェック |
| bochi-s3-push | Write/Edit | bochi データ S3 同期 |

### Stop hooks

| Hook | Matcher | 目的 |
|------|---------|------|
| check-console-log | * | console.log 残存チェック |
| forge-ace-session-complete | * | forge_ace セッション完了確認 |
| **gatekeeper-stop-check** | * | **HG-5 verdict 未報告警告** |
| cost-tracker | * | トークン・コスト追跡 |

## Rules 体系

`rules/` に共通ルール（`common/`）と言語別ルール（`typescript/`, `python/` 等）を配置。

| ルール | 内容 |
|--------|------|
| coding-style.md | 不変性、ファイルサイズ、エラーハンドリング |
| git-workflow.md | Conventional Commits、PR ワークフロー |
| testing.md | 80%+ カバレッジ、TDD 必須 |
| security.md | シークレット管理、OWASP Top 10 |
| performance.md | モデル選択戦略、コンテキスト管理 |
| development-workflow.md | リサーチ→計画→TDD→レビュー→コミット |
| quality-review.md | 8軸品質評価、VP-1〜VP-5 検証プロトコル |
| output-language.md | 日本語出力、英語コード |

## Agents

`agents/` に29種のサブエージェント定義。主要なもの:

| Agent | 目的 |
|-------|------|
| planner | 実装計画策定 |
| architect | システム設計 |
| code-reviewer | コードレビュー |
| tdd-guide | TDD 支援 |
| security-reviewer | セキュリティ分析 |
| build-error-resolver | ビルドエラー解決 |

## セットアップ

```bash
# シンボリックリンクで ~/.claude に接続（実体は常に my_dotfiles 側）
ln -sf ~/my_dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/my_dotfiles/claude/scripts ~/.claude/scripts
ln -sf ~/my_dotfiles/claude/rules ~/.claude/rules

# スキルもシンボリックリンク（二重管理を防止）
for skill in ~/my_dotfiles/claude/skills/*/; do
  name=$(basename "$skill")
  ln -sf "$skill" ~/.claude/skills/"$name"
done
```

**注意**: `cp` ではなく `ln -sf` を使用する。コピーすると同期が切れて二重管理になる。
実体は必ず `my_dotfiles/` 側に置き、`~/.claude/` からシンボリックリンクで参照する。

## プラグインマニフェストの注意点

`.claude-plugin/plugin.json` を編集する場合、Claude プラグインバリデータには未ドキュメントの厳密な制約がある。`agents` はディレクトリではなく明示的なファイルパスを使用する必要があり、`version` フィールドが必須。詳細は `PLUGIN_SCHEMA_NOTES.md` を参照。
