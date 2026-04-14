# Claude Code 設定 (my_dotfiles/claude)

Claude Code の全グローバル設定を dotfiles で一元管理するディレクトリ。
`~/.claude/` からシンボリックリンクで参照し、**実体は常にこちら**に置く。

## ディレクトリ構成

```
claude/
├── CLAUDE.md              # グローバル指示（全プロジェクト共通）
├── settings.json          # 本体設定 + フック定義（Claude Code が直接読む唯一の設定）
├── settings.local.template.json  # settings.local.json のテンプレート（実体は Git 管理外）
├── .gitignore             # ランタイムデータの除外設定
├── mcp-configs/           # MCP サーバー接続設定（プレースホルダー値で管理）
│   └── mcp-servers.json
├── skills-manifest.json   # 全スキルの一覧マニフェスト
├── scripts/hooks/         # フックスクリプト（settings.json から参照）
├── rules/                 # コーディング規約（common/ + 言語別）
├── skills/                # スキル定義（SKILL.md ベース）
├── agents/                # サブエージェント定義
├── commands/              # スラッシュコマンド定義
└── templates/             # プロジェクトテンプレート
```

## 管理方針

### dotfiles で管理するもの（Git 追跡対象）

| 対象 | 理由 |
|------|------|
| settings.json（hooks 含む） | Claude Code の全設定。フック定義もここに集約 |
| scripts/hooks/ | フックスクリプト本体 |
| rules/, agents/, commands/ | コーディング規約、エージェント、コマンド |
| skills/ | 自作スキル（Git リポジトリなし）＋ ECC 由来スキル |
| mcp-configs/ | MCP 接続先テンプレート（実キーは入れない） |
| CLAUDE.md, README.md 等 | ドキュメント |

### dotfiles で管理しないもの（Git 追跡外）

| 対象 | 理由 | 管理方法 |
|------|------|---------|
| settings.local.json | マシン固有の許可リスト（340+エントリ） | ローカルのみ |
| bochi-data/ | bochi の永続データ | S3 同期 |
| projects/ | プロジェクト別メモリ | セッション固有 |
| sessions/, plans/ | セッション履歴 | ランタイムデータ |
| plugins/ | プラグインキャッシュ | 再インストールで復元 |
| channels/ | Discord Bot 設定（トークン含む） | ローカルのみ |
| history.jsonl, file-history/ | 会話・編集履歴 | ランタイムデータ |

### スキルの管理体系

| 種別 | 管理方法 | 例 |
|------|---------|-----|
| **自作スキル（Git リポジトリあり）** | 個別リポジトリが本体。`~/.claude/skills/` に clone | bochi, my_pm_tools, forge_ace, figma-refine 等 |
| **自作スキル（Git リポジトリなし）** | dotfiles 配下で管理 | aidesigner-frontend |
| **ECC 由来スキル** | dotfiles 配下で管理 | coding-standards, tdd-workflow 等 |

## フック体系

`settings.json` の `hooks` キーに全13エントリを集約。
Claude Code はこのキーからのみフックを読み込む。

### PreToolUse（5個）

| Hook | Matcher | 目的 |
|------|---------|------|
| block-no-verify | Bash | `git --no-verify` をブロック |
| pm-pipeline-guard | Write | designs/ なしで plan.md 作成をブロック |
| forge-ace-dispatch-guard | Agent | forge_ace エージェント順序強制 |
| gatekeeper-pre-edit-guard | Edit\|Write | HG-1 未通過で src/ 編集ブロック |
| bochi-s3-pull-on-read | Read\|Grep | bochi データの S3 同期（読み取り前） |

### SessionStart（2個）

| Hook | Matcher | 目的 |
|------|---------|------|
| bochi-s3-pull | * | bochi データの S3 同期（セッション起動時） |
| skill-health-check | * | スキル/symlink の健全性チェック |

### PostToolUse（2個）

| Hook | Matcher | 目的 |
|------|---------|------|
| bochi-feedback-capture | Write\|Edit | ユーザーフィードバック記録 |
| bochi-s3-push | Write\|Edit | bochi データの S3 同期（書き込み後） |

### Stop（4個）

| Hook | Matcher | 目的 |
|------|---------|------|
| **claude-stop-notify** | * | **macOS 通知バナー + Glass 音（terminal-notifier）** |
| forge-ace-session-complete | * | forge_ace セッション完了確認 |
| gatekeeper-stop-check | * | gatekeeper HG-5 verdict 未報告警告 |
| gatekeeper-session-rotate | * | gatekeeper セッション履歴ローテーション |

## 自作スキル

### forge_ace — 5-Agent Quality Gate

| 項目 | 内容 |
|------|------|
| 起動 | `/forge_ace` |
| 目的 | コード修正の品質保証。Writer → Guardian → Overseer → PM-Admin → Designer の5エージェントゲート |
| Tier | Standard（コードのみ）/ Full（UI あり） |
| リポジトリ | GitHub（個別管理） |

### gatekeeper — 実装品質ゲート

| 項目 | 内容 |
|------|------|
| 起動 | `/gatekeeper` |
| 目的 | 「実機で動くか」を保証。仕様確認・推測修正禁止・仮説固執防止・実機検証を強制 |
| 連携 | forge_ace Full とペアで使用 |
| HARD GATE | HG-1 仕様確認 / HG-1.5 UX 思考 / HG-2 品質踏襲 / HG-3 推測修正禁止 / HG-4 仮説固執防止 / HG-5 実機検証 |

### bochi — PM の外部脳

| 項目 | 内容 |
|------|------|
| 起動 | `/bochi`、「考えて」「まとめて」「整理して」等 |
| 目的 | 思考・アイデア・コンテキスト追跡。S3 同期で永続化 |
| リポジトリ | GitHub（個別管理）、データは S3 管理 |

### requirements_designer — 要件定義

| 項目 | 内容 |
|------|------|
| 起動 | `/requirements_designer` |
| 目的 | インタラクティブ Q&A で要件定義 → designs/ に15ファイル生成 → Figma MCP 連携 |

### my_pm_tools — GitHub Projects PM

| 項目 | 内容 |
|------|------|
| 起動 | `/my_pm_tools` |
| 目的 | GitHub Projects V2 のPM支援。構築・運用・分析・移行を統合サポート |

### speckit-bridge — 要件→仕様変換

| 項目 | 内容 |
|------|------|
| 起動 | `/speckit-bridge` |
| 目的 | requirements_designer の出力を spec-kit 形式（spec.md + constitution.md）に変換 |

### figma-refine — Figma デザイン改善

| 項目 | 内容 |
|------|------|
| 起動 | `/figma-refine` |
| 目的 | Figma MCP + AIDesigner でデザイン改善。Level A/B 分類 + 3層検証 |

### pm-ad-analysis — 広告分析

| 項目 | 内容 |
|------|------|
| 起動 | `/pm-ad-analysis` |
| 目的 | Google/Meta/Apple/TikTok 広告の横断分析。15機能 × 5チャネル |

### pm-data-analysis — データ分析

| 項目 | 内容 |
|------|------|
| 起動 | `/pm-data-analysis` |
| 目的 | CSV/JSON/画像/MCP からの GAFA 水準分析。バイアス検出・因果推論 |

### aidesigner-frontend — UI 生成

| 項目 | 内容 |
|------|------|
| 起動 | `/aidesigner-frontend` |
| 目的 | AIDesigner MCP でフロントエンド・LP・ダッシュボード生成 |
| 管理 | dotfiles 配下（Git リポジトリなし） |

## セットアップ

新しいマシンに環境を構築する場合:

```bash
# 1. dotfiles を clone
git clone git@github.com:fideguch/my_dotfiles.git ~/my_dotfiles

# 2. Claude Code 設定をシンボリックリンクで接続
ln -sf ~/my_dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/my_dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/my_dotfiles/claude/README.md ~/.claude/README.md
ln -sf ~/my_dotfiles/claude/AGENTS.md ~/.claude/AGENTS.md
ln -sf ~/my_dotfiles/claude/.gitignore ~/.claude/.gitignore
ln -sf ~/my_dotfiles/claude/scripts ~/.claude/scripts
ln -sf ~/my_dotfiles/claude/rules ~/.claude/rules
ln -sf ~/my_dotfiles/claude/agents ~/.claude/agents
ln -sf ~/my_dotfiles/claude/commands ~/.claude/commands
ln -sf ~/my_dotfiles/claude/templates ~/.claude/templates
ln -sf ~/my_dotfiles/claude/mcp-configs ~/.claude/mcp-configs
ln -sf ~/my_dotfiles/claude/skills-manifest.json ~/.claude/skills-manifest.json

# 3. dotfiles 管理のスキルをシンボリックリンク
for skill in ~/my_dotfiles/claude/skills/*/; do
  name=$(basename "$skill")
  ln -sf "$skill" ~/.claude/skills/"$name"
done

# 4. 自作スキル（個別リポジトリ）を clone して symlink
for repo in bochi my_pm_tools forge_ace figma-refine speckit-bridge pm-data-analysis pm-ad-analysis requirements_designer; do
  git clone "git@github.com:fideguch/${repo}.git" ~/.claude/skills/"$repo" 2>/dev/null || true
done

# 5. settings.local.json をテンプレートからコピー（マシン固有設定）
cp ~/my_dotfiles/claude/settings.local.template.json ~/.claude/settings.local.json

# 6. mcp-configs の実キーを設定（プレースホルダーを置き換え）
# ~/.claude/mcp-configs/mcp-servers.json の YOUR_*_HERE を実際の値に編集

# 7. terminal-notifier をインストール（Stop hook 通知用）
brew install terminal-notifier
```

**原則**: `cp` ではなく `ln -sf` を使う。コピーすると同期が切れて二重管理になる。
実体は必ず `my_dotfiles/` 側に置き、`~/.claude/` からシンボリックリンクで参照する。
