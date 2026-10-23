# Claude Code — Global Configuration

## Language
- 説明・質問・回答は日本語。コード（変数名・コメント）・コミットメッセージ・PR 本文は英語
- ユーザー向けに生成するファイル（レポート・メモ・要件定義・Notion のページ）は見出し・本文とも日本語。スキルの英語テンプレートは、出力時に見出しを日本語にして使う（テンプレートファイルは直さない）
- 原語のまま：フレームワーク名・評価指標名（SCAMPER・E-E-A-T など）、機械が読む表のヘッダー、JSON・YAML のキー、CLI・パス

## Git
- Conventional Commits：`<type>: <description>`（feat・fix・refactor・docs・test・chore・perf・ci）
- PR は全コミット（`git diff <base>...HEAD`）を見て要約とテスト計画を書く。新しいブランチは `-u` で push

## コードを変える作業（資料・ノートだけの作業には適用しない）
- 主に TypeScript/JavaScript
- 既存プロジェクトでは、変更前にプロジェクトの `.claude/rules/` を読み、既存パターンに合わせる
- 複数ファイルにまたがる変更は、まず planner エージェントで計画。コードを書いたら code-reviewer エージェント
- 既存コードの変更は forge_ace、新規コードは TDD（詳細は `rules/common/development-workflow.md`。コードを読んだときに読まれる）
- forge_ace は最初に実行フォルダ（brief・報告・NEXT。`~/.claude/forge-ace/runs/`）を作り、Standard 以上はターミナル（tmux）で回す。Claudian など他のアプリの中のセッションは、そのアプリと一緒に止まる（forge_ace の Step 0）
- Figma の URL → Figma MCP（`get_design_context`）でデザインを取ってから実装。Figma を操作したら DESIGN.md の「HEAL」節に従う
- 品質評価（review・evaluation・assessment、GAFA 6 軸・8 軸）を頼まれたら `quality-review` スキル

## Project Health
- SessionStart で CLAUDE.md・`.claude/`・`.mcp.json` の有無を点検する。`/health` で雛形を作るのは Git リポジトリのときだけ（Git 管理しないフォルダ、例えば Obsidian の保管庫には作らない）
