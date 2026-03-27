# Claude Code — Global Configuration

## Communication
- **Default language**: 日本語（説明・質問・回答すべて）
- **Code artifacts**: English only（変数名、コメント、コミットメッセージ、PR本文）
- 説明とコードを切り替える際は言語も切り替える

## Primary Stack
TypeScript/JavaScript（メイン）。
プロジェクト固有の CLAUDE.md がない場合は `rules/typescript/` を優先適用。

## Configuration Map

| Layer | Location | Purpose |
|-------|----------|---------|
| Rules | `~/.claude/rules/` | コーディング、テスト、セキュリティ、Git の規約 |
| Skills | `~/.claude/skills/` | タスク別の詳細リファレンス |
| Agents | `~/.claude/agents/` | 専門サブエージェント |
| Hooks | `~/.claude/hooks/hooks.json` | 自動化ワークフロー（pre/post-tool） |

## Git
- コミットメッセージは英語、Conventional Commits 形式（詳細は `rules/common/git-workflow.md`）

## Workflow Defaults
- マルチファイルタスク → まず **planner** エージェントで計画
- コード記述後 → 指示なしで **code-reviewer** エージェントを実行
- Figma URL → Figma MCP (`get_design_context`) でデザイン取得してからUI実装
- Notion → `rules/common/notion.md` に従ってから書き込み
- プロダクト開発パイプライン → `rules/common/team-pipeline.md` に従う

## Quality
- スキル改善・パイプライン・Stage Gate → `rules/common/team-pipeline.md`
- Figma MCP 操作後 → DESIGN.md「HEAL」セクションに従う

## Project Health
- SessionStart 時にプロジェクト健全性を自動チェック（CLAUDE.md, .claude/, .mcp.json の有無）
- 欠落がある場合は `/health` でスキャフォールド可能
- MCP 選定基準 → `rules/common/mcp-selection.md`
