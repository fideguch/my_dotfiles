# speckit-bridge

requirements_designer の出力（`designs/`）を [GitHub spec-kit](https://github.com/github/spec-kit) の仕様書形式に変換するスキル。

## 何をするスキルか

PMが `/requirements_designer` で作った要件ドキュメント（7ファイル）を、エンジニアが `specify plan → tasks → implement` で実装できる形式（`spec.md` + `constitution.md` + `conventions.md`）に自動変換します。さらに ESLint/boundaries/Husky による多層ドリフト防止を設定します。

```
/requirements_designer → designs/ (PM成果物)
        ↓
/speckit-bridge → spec.md + constitution.md + conventions.md (Engineer入力)
        ↓
/speckit.plan → plan.md, data-model.md, contracts/
        ↓
/speckit.tasks → tasks.md
        ↓
/speckit.implement → コード
```

## 前提条件

- `/requirements_designer` で `designs/` が生成済みであること
- 品質スコアが 70 点以上（推奨）
- spec-kit CLI がインストール済みであること

```bash
# spec-kit CLI のインストール（初回のみ）
# ⚠️ PyPI の "specify" は別パッケージです。必ず以下のコマンドを使ってください。
uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git@v0.4.3"

# uv がない場合は先にインストール
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## 使い方

### 基本

```
要件をspec-kitに変換して
```

または

```
/speckit-bridge
```

### トリガーワード

- `speckit-bridge` / `spec-kit変換` / `仕様変換`
- `要件をspec-kitに変換` / `spec.mdを生成`
- `エンジニアに渡せる形にして`
- `bridge to spec-kit` / `convert to spec`

## ワークフロー（7ステップ）

| Step | 名称 | 概要 |
|------|------|------|
| 0 | Validation | `designs/` の存在・必須ファイル・品質スコアを検証 |
| 1 | Initialize spec-kit | `.specify/` が未作成なら `specify init` を実行 |
| 1.5 | Project Structure Setup | ディレクトリ構造チェック、`.gitignore` 更新、`CLAUDE.md` 規約追記を提案 |
| 2 | Generate Constitution | `designs/README.md` → `.specify/memory/constitution.md`（開発原則・制約） |
| 2.5 | Generate Conventions | `designs/` 全体 → `.specify/memory/conventions.md`（命名規約・構造規約・ビジネスルール） |
| 2.6 | Generate Enforcement Scaffold | ESLint naming-convention + eslint-plugin-boundaries + Husky pre-commit を設定提案 |
| 3 | Create Feature Branch & Spec | プロジェクト名から feature branch を作成し、spec ディレクトリを準備 |
| 4 | Generate spec.md | 全 `designs/` ファイルを統合し、spec-kit テンプレート形式の `spec.md` を生成 |
| 5 | Quality Validation | spec-kit チェックリストで品質検証（最大3イテレーション） |
| 6 | Report Completion | 変換サマリー・Anti-Drift 状況・次のステップを報告 |

### Step 0: Validation

- `designs/` ディレクトリの存在確認
- 必須: `README.md`, `functional_requirements.md`（FR-001 存在確認）, `user_stories.md`（US-001 存在確認）
- 任意: `non_functional_requirements.md`, `ubiquitous_language.md`, `ui_design_brief.md`
- 品質スコア未算出 or 70点未満の場合は警告（ユーザー判断で続行可）

### Step 1 / 1.5: 初期化とプロジェクト構造整理

- `specify init --here --ai claude --force` で `.specify/` を初期化（未作成時のみ）
- ディレクトリ存在状況を表形式で表示
- `.gitignore` に `.claude/` が無ければ追記提案
- `CLAUDE.md` に `## Directory Structure` セクションが無ければ追記提案
- 全変更はユーザー確認後に実行

### Step 2 / 2.5 / 2.6: Constitution + Conventions + Enforcement

Step 2〜2.6 の詳細は後述の「多層ドリフト防止」セクションを参照。

### Step 3-4: Feature Branch と spec.md 生成

- `designs/README.md` からプロジェクト名を取得し、kebab-case の feature branch を作成
- 全 `designs/` ファイルを読み込み、spec-kit テンプレート形式で `spec.md` を生成
- FR は "System MUST" 形式に変換、US は Priority (P1/P2/P3) 付き User Story に変換

### Step 5-6: 品質検証と完了レポート

- `.specify/templates/checklist-template.md` を参照し品質チェックリストを生成
- 不合格項目があれば spec.md / conventions.md を修正（最大3回）
- 完了時に変換サマリー・Anti-Drift 状況・次のステップを報告

## 多層ドリフト防止

Claude Code はセッション間で設計判断を保持できず、命名規約・ディレクトリ構造・API設計がドリフトします。speckit-bridge は4層の防御でこれを防ぎます。

| Layer | 仕組み | 遵守率 | 生成 Step |
|-------|--------|--------|----------|
| L1: Intent | `conventions.md` — 命名規約・構造規約・ビジネスルールを宣言 | ~60% | Step 2.5 |
| L2: Guard (naming) | ESLint `@typescript-eslint/naming-convention` — 命名をランタイムで強制 | ~95% | Step 2.6a |
| L2: Guard (boundary) | `eslint-plugin-boundaries` — import 依存関係をランタイムで強制 | ~95% | Step 2.6b |
| L3: Gate | Husky pre-commit + lint-staged — コミット時にLintエラーをブロック | ~100% | Step 2.6c |

### conventions.md（Step 2.5）

`designs/` 全体から生成される50行以下の薄いリファレンス。5セクション構成:

1. **Directory Structure** -- ファイル配置パターン（singular PascalCase 等）
2. **Database** -- テーブル命名（snake_case plural）、PK/FK 規約
3. **API** -- ベースパス、エンベロープ形式、エラー形式
4. **Business Rules** -- スキーマ/リンターで表現不可能なルール（FR から抽出）
5. **Design Tokens** -- DESIGN.md 存在時のトークン命名パターン

ソース優先順位: `ubiquitous_language.md` > `functional_requirements.md` > `README.md` > `non_functional_requirements.md`

既存コードがある場合は既存パターンに合わせて生成（Enhance モード）。

### Enforcement Scaffold（Step 2.6）

段階的に導入。このステップでは Phase A のみ設定:

| Phase | タイミング | ツール |
|-------|-----------|--------|
| A (MVP) | プロジェクト初日 | ESLint naming + boundaries + Husky |
| B | 3つ目のエンティティ追加時 | plop.js（ファイル生成テンプレート） |
| C | API外部公開時 | Spectral + prisma-lint |

Non-TypeScript 対応: Python → `ruff`, Go → `golangci-lint`。対応外言語は conventions.md のみ。

## 変換マッピング

| designs/ ファイル | spec-kit 出力先 | 変換内容 |
|---|---|---|
| `README.md` | `constitution.md` | 目的・原則・制約・成功指標 |
| `README.md` | `spec.md` Success Criteria | 成功の定義 → SC-001 形式 |
| `README.md` | `spec.md` Assumptions | 制約・前提条件 |
| `functional_requirements.md` | `spec.md` Functional Requirements | FR-001 → "System MUST" 形式 |
| `functional_requirements.md` | `spec.md` Edge Cases | 各 FR の例外フロー |
| `functional_requirements.md` | `conventions.md` Section 4 | スキーマ外ビジネスルール |
| `non_functional_requirements.md` | `spec.md` Assumptions | NFR 目標値を制約として |
| `non_functional_requirements.md` | `constitution.md` Quality Standards | 主要 NFR を品質基準に |
| `user_stories.md` | `spec.md` User Scenarios & Testing | US → User Story (P1/P2/P3) |
| `ubiquitous_language.md` | `spec.md` Key Entities | UL 用語 → エンティティ |
| `ubiquitous_language.md` | `conventions.md` Sections 1-5 | 命名規約・構造規約 |
| `ui_design_brief.md` | `spec.md` User Scenarios (Screen Ref) | SCR-XXX <-> US-XXX マッピング |
| `ui_design_brief.md` | `constitution.md` Design Artifacts | Figma URL 参照 |
| DESIGN.md (root) | `conventions.md` Section 5 | トークン命名規約の継承 |
| DESIGN.md (root) | `constitution.md` Design Artifacts | HEAL/SYNC プロトコル参照 |

## 生成されるファイル

```
.specify/
  memory/
    constitution.md          ← プロジェクトの開発原則・Architecture Governance
    conventions.md           ← 命名規約・構造規約・ビジネスルール（50行以下）
specs/
  [feature-name]/
    spec.md                  ← 統合仕様書
    checklists/
      requirements.md        ← 品質チェックリスト
```

加えて、以下の設定ファイルの追加・更新を提案（ユーザー確認後に実行）:

| ファイル | 内容 |
|---------|------|
| `.eslintrc` / `eslint.config.js` | naming-convention + boundaries ルール |
| `.husky/pre-commit` | `npx lint-staged` |
| `package.json` (lint-staged) | `*.{ts,tsx}` → `eslint --fix` |

## プロジェクト構造の自動整理

Bridge 発動時に、プロジェクトのディレクトリ構造を自動チェックし整理を提案します:

- ディレクトリの存在状況を表形式で表示
- `.gitignore` の確認・不足エントリの追記提案（`.claude/` 等）
- プロジェクト `CLAUDE.md` にディレクトリ規約の追記提案

```
my-project/
├── designs/         ← PM成果物（Git追跡: Yes）
├── .specify/        ← spec-kit 設定（Git追跡: Yes）
├── specs/           ← 仕様書・計画書（Git追跡: Yes, feature branch）
├── src/             ← 実装コード（Git追跡: Yes）
├── tests/           ← テスト（Git追跡: Yes）
├── .claude/         ← Claude Code 設定（Git追跡: No）
├── .gitignore
├── CLAUDE.md
└── package.json
```

全ての変更はユーザー確認後に実行されます（勝手にファイルを変更しません）。

## 品質ゲート

- 品質スコア 70 点以上: そのまま変換
- 品質スコア 70 点未満: 警告を表示、ユーザー判断で続行可
- 品質スコア未算出（`-/100`）: `/requirements_designer` の Phase 4A 実行を推奨
- spec.md 生成後に品質チェックリストを実行（最大3イテレーションで修正）

## 変換後の次のステップ

| コマンド | 誰が実行 | 生成物 |
|---------|---------|--------|
| `/speckit.plan` | Tech Lead | plan.md, data-model.md, contracts/ |
| `/speckit.tasks` | Tech Lead | tasks.md（依存関係付き） |
| `/speckit.clarify` | PM | [NEEDS CLARIFICATION] の解決 |
| `/speckit.implement` | Engineer | コード |

成長時の追加ツール（Step 6 で案内）:

| タイミング | ツール |
|-----------|--------|
| 3つ目のエンティティ追加時 | plop.js（ファイル生成テンプレート） |
| API外部公開時 | Spectral（OpenAPIリンター）+ prisma-lint |

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| `designs/` が存在しない | `/requirements_designer` の実行を促す |
| `FR-001` が存在しない | Phase 2（機能要件の抽出）の完了を促す |
| `US-001` が存在しない | Phase 4B（ユーザーストーリー生成）の完了を促す |
| 品質スコア < 70 | 警告表示、ユーザー判断でオーバーライド可 |
| 品質スコア未算出（`-/100`） | Phase 4A の実行を推奨、ユーザー判断で続行可 |
| `specify` CLI が見つからない | `uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git@v0.4.3"` を案内 |
| `.specify/` が存在しない | `specify init --here --ai claude --force` を実行 |
| UL 未定義 | FR からエンティティを推定し、UL 定義を推奨する警告を表示 |
| 既存コードとの規約不一致 | Enhance モードで既存パターンに合わせ、差異をユーザーに確認 |

## 言語サポート

| 対象 | 言語 |
|------|------|
| SKILL.md | 英語（Claude Code 規約） |
| ユーザー出力（レポート等） | 日本語（CLAUDE.md Communication ルール準拠） |
| spec.md セクションヘッダ | 英語（spec-kit テンプレート準拠） |
| FR/US/NFR ID | 英語（`FR-001`, `US-001` 等） |
| エンティティ名 | 英語（後続の `specify plan` が英語前提） |
| 説明文・ストーリー本文 | 英語推奨（日本語も許容。ただし `specify plan` 出力品質低下の可能性を警告） |

## Roadmap

| 機能 | ステータス | 説明 |
|------|----------|------|
| conventions.md 生成 | ✅ 実装済み | Step 2.5: 命名規約・構造規約・ビジネスルールの自動生成 |
| ESLint / boundaries 連携 | ✅ 実装済み | Step 2.6: naming-convention + eslint-plugin-boundaries + Husky |
| Issue巻き戻し | 未実装 | 実装スコープへのフィードバックによる要件差し戻し機能 |

## 関連スキル

- `/requirements_designer` -- 要件定義（このスキルの入力を生成）
- `/writing-plans` -- 実装計画（spec-kit を使わない場合の代替）
- `/brainstorming` -- アイデアが固まらない段階で使用
