# Team Development Pipeline

> Extracted from global CLAUDE.md to keep identity config concise.
> This file is auto-loaded as a rule and applies to all product development work.

## Skill Maintenance

- **スキル改善リマインド（週1回）**: 自作スキル（requirements_designer, set-up-github-project, pm-data-analysis, pm-ad-analysis, speckit-bridge 等）の使用時に、その週まだ提案していなければ、GitHub上の同カテゴリ最新スキル（awesome-agent-skills, alirezarezvani/claude-skills, deanpeters/Product-Manager-Skills 等）と構造・機能・UXを比較し、改善案をその場で提案する。前回提案日は `memory/last_skill_review.md` に記録し、7日以上経過していなければスキップする
- **pm-ad-analysis 自己評価（月1回）**: pm-ad-analysis スキル使用時に `memory/last_skill_review.md` の `last_ad_analysis_self_eval` を確認。30日以上経過していれば、バックグラウンドエージェントで以下を実行し、結果をユーザーに提案する：
  1. SKILL.md の行数・構造を検証（目標: 400行以下、`<HARD-GATE>`形式維持）
  2. references/ の内容鮮度チェック（広告プラットフォームの仕様変更に追従しているか）
  3. リファクタリング案があれば費用対効果を試算（改善時間 vs 信頼性向上%）
  4. 費用対効果が正の場合のみユーザーに提案。負の場合はスキップして日付のみ更新

## Quality Improvement Flow

- スキル改善時 → 10次元世界基準評価を実施（要件方法論/Q&A設計/テスト/Figma統合/DESIGN.md/日本市場/パイプライン/ドキュメント/Design-as-Code/拡張性）
- 70未満の次元 → 改善計画を提案
- Figma MCP 操作後 → プロジェクトの DESIGN.md「HEAL」セクションの自己修復プロトコルに従う
- DESIGN.md ↔ Figma Variables の整合性をフェーズ移行時に検証（SYNC セクション参照）

## Pipeline Enforcement

プロダクト開発は以下の順序を必ず守る。前工程の完了なしに後工程を開始しない。

```
/brainstorming（任意）
  ↓
/requirements_designer → designs/ 生成（品質スコア 70点以上で次へ）
  ↓
/speckit-bridge → specs/[feature]/spec.md 生成
  ↓
specify plan → plan.md + research.md + data-model.md + contracts/
  ↓
specify tasks → tasks.md（依存関係付きタスクリスト）
  ↓
/writing-plans または specify implement → 実装
```

- `designs/` が存在しない状態で実装計画の作成を禁止
- 品質スコア 70点未満の要件は `/speckit-bridge` に渡さない
- 各ステップ間でPM確認を挟む

## Stage Gate Criteria

| Gate | From → To | Criteria |
|------|-----------|----------|
| G1 | Requirements → Spec | 品質スコア ≥70, US生成済み, Must FR に AC あり |
| G2 | Requirements → UI Design | G1 + UL定義済み or スキップ根拠あり |
| G3 | Requirements → PRD | 品質スコア ≥80 |
| G4 | UI Design → Frontend | UIスコア ≥70, トークン同期済み |

## Downstream Skill Contracts

| 下流スキル | 必須入力 | オプション |
|-----------|----------|-----------|
| /writing-plans | designs/README.md, functional_requirements.md, user_stories.md | non_functional_requirements.md |
| /speckit-bridge | designs/*.md 全体 | — |
| /frontend-design | designs/ui_design_brief.md | DESIGN.md トークン |

## PM → Engineer Handoff

- **PM成果物**: `designs/`（requirements_designer output）
- **Bridge**: `/speckit-bridge` で `designs/` → `specs/[feature]/spec.md` に構造化
- **Engineer入力**: `specs/` 配下の spec.md, plan.md, tasks.md
- 全ハンドオフは GitHub Issue に記録する

## Role-Based Skill Access

| Role | Primary Skills | Agents |
|------|---------------|--------|
| PM | /requirements_designer, /brainstorming, /pm-* skills, /pm-data-analysis, /pm-ad-operations | planner |
| Tech Lead | /writing-plans, spec-kit plan/tasks | planner, architect |
| Engineer | spec-kit implement, /tdd-workflow | code-reviewer, tdd-guide, build-error-resolver |
| Designer | Phase 5 (Figma MCP), /ui-ux-pro-max, /frontend-design | — |

## MCP Selection by Project Type

プロジェクト単位で必要な MCP のみ有効化する（常時10個以下を推奨）。
詳細は [mcp-selection.md](./mcp-selection.md) を参照。

| Project Type | Recommended MCPs |
|-------------|-----------------|
| SaaS Product | GitHub, Linear, Figma, GA4, BigQuery |
| Growth / Marketing | GitHub, GA4, Google Ads, Meta Ads, BigQuery |
| Platform / Infra | GitHub, Linear, Supabase, ClickHouse |
| Default（最小） | GitHub, Linear, Figma |
