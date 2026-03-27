---
name: speckit-bridge
description: >-
  Convert requirements_designer output (designs/) into spec-kit format (spec.md + constitution.md + conventions.md).
  Bridges PM requirements workflow to engineer implementation pipeline with multi-layered anti-drift defense
  (conventions.md for intent + ESLint/boundaries for enforcement + pre-commit for gating).
  Use after /requirements_designer completes with quality score >= 70.
type: automation
best_for:
  - "Connecting requirements_designer output to spec-kit pipeline"
  - "Converting FR/NFR/US documents into a unified spec.md"
  - "Generating project constitution from project charter"
  - "Enabling PM → Engineer handoff via structured specifications"
triggers:
  - "speckit-bridge"
  - "spec-kit変換"
  - "仕様変換"
  - "要件をspec-kitに変換"
  - "spec.mdを生成"
  - "エンジニアに渡せる形にして"
  - "bridge to spec-kit"
  - "convert to spec"
---

# Speckit Bridge

requirements_designer の出力（`designs/`）を spec-kit の仕様書形式（`spec.md` + `constitution.md`）に変換するスキル。

---

## Prerequisites

1. `designs/` ディレクトリが存在し、少なくとも以下が含まれること:
   - `designs/README.md`（プロジェクト憲章）
   - `designs/functional_requirements.md`（FR-001 以上の要件）
   - `designs/user_stories.md`（US-001 以上のストーリー）
2. spec-kit CLI がインストール済み: `specify --help` で確認
3. 品質スコアが 70 点以上であること（未達の場合は警告し `/requirements_designer` への差し戻しを提案）

---

## Workflow

### Step 0: Validation

1. `designs/` ディレクトリの存在を確認
2. 必須ファイルの存在チェック:
   - `designs/README.md` → 必須
   - `designs/functional_requirements.md` → 必須（FR-001 の存在も確認）
   - `designs/user_stories.md` → 必須（US-001 の存在も確認）
   - `designs/non_functional_requirements.md` → 任意
   - `designs/ubiquitous_language.md` → 任意
   - `designs/ui_design_brief.md` → 任意（変換対象外、Figma 成果物として別管理）
3. 品質スコアの確認:
   - `designs/functional_requirements.md` の Document Info セクションから「品質スコア」または「Quality Score」フィールドを読み取る
   - 形式は `XX/100` または `-/100`（未算出）
   - **未算出（`-/100`）の場合**: 「品質スコアが未算出です。/requirements_designer の Phase 4A で品質評価を実行してください。このまま変換を続けますか？」と警告
   - **70 点未満の場合**: 「品質スコアが [XX]/100 です（推奨: 70点以上）。/requirements_designer で品質を改善してから変換することを推奨します。このまま変換を続けますか？」と警告
   - ユーザーが続行を選択した場合のみ進む

### Step 1: Initialize spec-kit Project

プロジェクトルートに `.specify/` が存在しない場合:

```bash
specify init --here --ai claude --force
```

既に存在する場合はスキップ。

### Step 1.5: Project Structure Setup

Bridge 発動時にプロジェクトのディレクトリ構造を整理する。全サブステップでユーザー確認を挟み、勝手にファイルを変更しない。

#### 1.5a: ディレクトリ構造チェック

プロジェクトルートのディレクトリをスキャンし、存在状況を表形式で表示する:

```
Project Structure Check

| Directory | Status | Owner | Git |
|-----------|--------|-------|-----|
| designs/  | [exists/missing] | PM | Yes |
| .specify/ | [exists/missing] | Auto | Yes |
| specs/    | [will be created] | PM->TL | Yes (feature branch) |
| src/      | [exists/missing] | Eng | Yes |
| tests/    | [exists/missing] | Eng | Yes |
| .claude/  | [exists/missing] | Auto | No (.gitignore) |
```

#### 1.5b: .gitignore の確認・更新

1. `.gitignore` が**存在しない場合**:
   - プロジェクトの言語を検出（`package.json` → Node.js, `pyproject.toml` → Python, `go.mod` → Go 等）
   - 適切な .gitignore を生成提案（以下はベース + 言語別エントリ）
2. `.gitignore` が**存在する場合**:
   - `.claude/` エントリがなければ追記を提案
   - 他のエントリは変更しない

ベース .gitignore テンプレート:
```gitignore
# Claude Code (project-level settings may contain sensitive info)
.claude/

# OS files
.DS_Store
Thumbs.db

# Dependencies (language-specific)
node_modules/
__pycache__/
.venv/
```

**Git で追跡すべきもの（.gitignore に入れない）:**
- `designs/` — PM成果物のトレーサビリティ確保
- `.specify/` — spec-kit の設定・テンプレート
- `specs/` — 仕様書・計画書

追記は必ず「.gitignore に以下を追加してよいですか？」とユーザー確認後に実行する。

#### 1.5c: CLAUDE.md ディレクトリ規約

- プロジェクトルートに `CLAUDE.md` が**存在する場合**: `## Directory Structure` セクションがなければ追記を提案
- `CLAUDE.md` が**存在しない場合**: スキップ（新規作成はユーザー判断に委ねる）

追記テンプレート:
```markdown
## Directory Structure

| Directory | Owner | Git | Purpose |
|-----------|-------|-----|---------|
| designs/  | PM    | Yes | Requirements (requirements_designer output) |
| .specify/ | Auto  | Yes | spec-kit config, templates, scripts |
| specs/    | PM→TL | Yes | Specifications, plans, tasks (per feature branch) |
| src/      | Eng   | Yes | Production code |
| tests/    | Eng   | Yes | Test code |
| .claude/  | Auto  | No  | Claude Code project settings |

## Project Conventions

Naming decisions: `.specify/memory/conventions.md`
ESLint enforces structure: `eslint-plugin-boundaries` rules
New entity? → Add to conventions.md first, then implement.
```

#### 1.5d: 構造に関するユーザー確認

全チェック結果を表示した上で「この構造で進めますか？」と確認してから Step 2 に進む。

---

### Step 2: Generate Constitution

`designs/README.md` を読み込み、`.specify/memory/constitution.md` を生成する。

#### Mapping Rules

| designs/README.md セクション | constitution.md セクション |
|---|---|
| 2. 背景と目的 → 成功の定義 | Core Principles → I. Success Metrics |
| 4. やりたいこと → 優先順位 | Core Principles → II. Scope Boundaries |
| 5. 制約・前提条件 | Additional Constraints |
| 6. 品質に関する期待値 | Quality Standards |

#### Generation Template

constitution.md はプロジェクトの **開発原則・アーキテクチャ制約** を定義するファイル。
KPI やスコープ境界は spec.md の Success Criteria / Assumptions に記載するため、ここには含めない。

```markdown
# [プロジェクト名] Constitution

## Core Principles

### I. Quality Gate (NON-NEGOTIABLE)
Requirements quality score must be >= 70 before implementation.
All functional requirements must have testable acceptance criteria.
TDD mandatory: tests written before implementation.

### II. Scope Discipline
[designs/README.md セクション4「やりたいこと」の Out of Scope から抽出し、
 「以下は本プロジェクトでは実装しない」形式の原則に変換]

### III. [プロジェクト固有の開発原則]
[designs/README.md セクション5「制約・前提条件」から技術制約を抽出し、
 開発原則として記述。例: "Mobile-First", "Offline-Ready", "API-First" 等]

## Technical Constraints
[designs/README.md セクション5 の技術的制約（予算、期限、技術スタック制限等）]
[designs/non_functional_requirements.md の主要 NFR 目標値（存在する場合）]

## Development Workflow
- Requirements: /requirements_designer → designs/
- Specification: /speckit-bridge → spec.md
- Pipeline: specify plan → specify tasks → specify implement
- All changes must trace back to a FR or US

## Architecture Governance

### Convention Authority
- `.specify/memory/conventions.md` defines naming decisions (thin reference)
- ESLint + eslint-plugin-boundaries enforce code structure at commit time
- New entities MUST be added to conventions.md before implementation

### Decision Freeze
Frozen at spec time (change requires /speckit-bridge re-run):
- Response envelope format
- Error response format
- Database naming pattern
- Directory structure rules

### Business Rules Registry
Business rules that cannot be expressed in schema/linter
are documented in conventions.md Section 4.
These are the highest-drift-risk items — review them at every PR.

## Design Artifacts

[designs/ui_design_brief.md または DESIGN.md が存在する場合のみこのセクションを生成。
 両方存在しない場合はセクション自体をスキップ]

### Source of Truth Hierarchy
1. DESIGN.md (project root) — Design tokens, component patterns, Figma API rules
2. Figma design file — Visual source of truth (wireframes, mockups)
3. designs/ui_design_brief.md — Design intent, platform strategy, brand colors

### For Engineers
- UI implementation: Read DESIGN.md first, then reference Figma file
- Token naming: Follow conventions.md Section 5
- New UI component: Check Figma design file for existing patterns before creating
- DESIGN.md HEAL protocol: Apply after every Figma MCP operation
- DESIGN.md SYNC protocol: Verify token consistency at phase transitions

### Figma File
[designs/ui_design_brief.md Section 6 から Figma URL を抽出して記載。存在しない場合は "Not yet created" と記載]

## Governance
- Constitution is generated from requirements_designer output
- Updates require re-running /requirements_designer and /speckit-bridge
- Constitution supersedes ad-hoc decisions during implementation
- conventions.md is a derived artifact — never edit manually

**Version**: 2.1 | **Generated**: [DATE] | **Source**: designs/README.md
```

### Step 2.5: Generate Conventions (Anti-Drift)

`designs/` 全体を読み込み、`.specify/memory/conventions.md` を生成する。
このファイルはプロジェクトの **命名規約・構造規約・スキーマ外ビジネスルール** を定義する薄いリファレンス（50行以下）。

#### Why conventions.md が必要か

Claude Code はセッション間で設計判断を保持できず、以下がドリフトする:
- ディレクトリ構造（ファイル配置がバラバラ）
- API設計（エンドポイント命名、レスポンス形式）
- DBスキーマ（テーブル命名、カラム規約）

conventions.md は「意図の宣言」として機能する（遵守率 ~60%）。
ランタイム強制は Step 2.6 の ESLint ルールが担う（遵守率 ~100%）。

#### ソース

- `designs/ubiquitous_language.md` Section 2 (Glossary) + Section 4 (Naming Rules) — 存在する場合
- `designs/README.md` Section 5 (技術制約・スタック情報)
- `designs/functional_requirements.md` (ビジネスルール、CRUD 動詞からエンティティ抽出)
- `designs/non_functional_requirements.md` (DB/API 制約)

#### Generation Template

```markdown
# [Project] Conventions

> Source: designs/ubiquitous_language.md | Generated: [DATE]
> Changes require re-running /speckit-bridge. Do NOT edit manually.

## 1. Directory Structure
- Domain entities: src/models/ (singular PascalCase)
- Business logic: src/services/ ([Entity]Service)
- API handlers: src/routes/ ([entity].route.ts)
- Data access: src/repositories/ ([Entity]Repository)
- New entity? Add to this list first, then implement.

## 2. Database
- Tables: snake_case plural (orders, order_items)
- PK: id (UUID v7) | FK: [table_singular]_id
- Timestamps: created_at, updated_at, deleted_at
- Boolean: is_[adj] or has_[noun]
- Soft delete only. Never physical delete.

## 3. API
- Base: /api/v1/[resource-plural-kebab]
- Envelope: { data, meta?, error? }
- Error: { code: "UPPER_SNAKE", message, details? }
- Auth: [Bearer JWT / Session — from designs/non_functional_requirements.md]

## 4. Business Rules (schema/linter で表現不可能)
[designs/functional_requirements.md の各FRのビジネスルールから、
 スキーマやリンターで自動強制できないルールを抽出]
- BR-001: [ルール記述] (Source: FR-XXX)

## 5. Design Tokens
[DESIGN.md が存在する場合: トークンセクションから命名パターンを読み取り反映]
[存在しない場合: 汎用的な命名規約のみ]
- Source: DESIGN.md → Figma Variables → CSS custom properties
- Naming: --color-[role], --spacing-[scale], --font-[role]
- Grid: 8pt scale (4/8/12/16/24/32/48/64px)
- Token changes: Update DESIGN.md first, then sync Figma.
```

#### UL が存在しない場合のフォールバック

`designs/ubiquitous_language.md` が存在しない場合:
1. `designs/functional_requirements.md` の Actor, Postcondition から主要な名詞を抽出
2. プロジェクトルートの `package.json`, `go.mod`, `pyproject.toml` 等から tech stack を検出し、ディレクトリパターンを推定
3. 以下の警告を出力:
   > ⚠️ UL 定義が不足しています。ドリフトリスクが高い状態です。`/requirements_designer` Phase 4C でユビキタス言語を定義することを強く推奨します。

#### Existing Codebase Compatibility（Enhance モード）

`src/` ディレクトリに既存コードがある場合:
1. 既存のファイル命名パターンをスキャン（PascalCase? camelCase?）
2. 既存のディレクトリ構造を検出
3. conventions.md は既存パターンに合わせて生成する（新パターンを押し付けない）
4. 不一致がある場合はユーザーに確認

---

### Step 2.6: Generate Enforcement Scaffold

conventions.md と同時に、**コードレベルで規約を強制する設定ファイル**を生成提案する。
ドキュメント（conventions.md）だけではAIの遵守率は50-70%。ESLint等のランタイム強制で95%+に引き上げる。

ESLint のエラーメッセージは「AI教師信号」として機能する — AIがエラーを受け取ると2-3回の反復で規約パターンを学習する。

**全サブステップでユーザー確認を挟む。既存設定がある場合は差分のみ提案。**

#### 段階的導入ガイド

| Phase | タイミング | 追加ツール |
|-------|-----------|-----------|
| A (MVP) | プロジェクト初日 | ESLint naming-convention + eslint-plugin-boundaries + Husky |
| B | 3つ目のエンティティ追加時 | plop.js（ファイル生成テンプレート） |
| C | API外部公開時 | Spectral（OpenAPIリンター）、prisma-lint |

**Phase A のみ** をこのステップで設定する。Phase B/C は Step 6 の Next Steps で案内する。

#### 2.6a: ESLint naming-convention（TypeScript の場合）

`designs/ubiquitous_language.md` Section 4 の Target Stack から言語を検出。
TypeScript プロジェクト（`package.json` + `tsconfig.json` 存在）の場合:

```javascript
// 追加提案する ESLint ルール
{
  rules: {
    '@typescript-eslint/naming-convention': [
      'error',
      { selector: 'class', format: ['PascalCase'] },
      { selector: 'interface', format: ['PascalCase'],
        custom: { regex: '^I[A-Z]', match: false } },
      { selector: 'variable', format: ['camelCase', 'UPPER_CASE'] },
      { selector: 'variable', types: ['boolean'],
        format: ['camelCase'], prefix: ['is', 'has', 'should'] },
    ],
  }
}
```

ESLint が未導入の場合はスキップし、Step 6 で導入を推奨する。

#### 2.6b: eslint-plugin-boundaries

conventions.md Section 1 のディレクトリ構造ルールから import 境界ルールを生成。

```javascript
// 追加提案する eslint-plugin-boundaries 設定
{
  settings: {
    'boundaries/elements': [
      { type: 'models', pattern: 'src/models/*' },
      { type: 'services', pattern: 'src/services/*' },
      { type: 'routes', pattern: 'src/routes/*' },
      { type: 'repositories', pattern: 'src/repositories/*' },
    ],
  },
  rules: {
    'boundaries/element-types': ['error', {
      default: 'disallow',
      rules: [
        { from: 'routes', allow: ['services'] },
        { from: 'services', allow: ['repositories', 'models'] },
        { from: 'repositories', allow: ['models'] },
      ],
    }],
  },
}
```

#### 2.6c: Husky pre-commit hook

```bash
# .husky/pre-commit に追加提案
npx lint-staged
```

```json
// package.json の lint-staged に追加提案
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix"]
  }
}
```

Husky が未導入の場合: `npx husky init` の実行を提案。

#### Non-TypeScript プロジェクトの場合

- **Python**: `ruff` の naming convention ルールを提案
- **Go**: `golangci-lint` の `revive` ルールを提案
- **その他**: conventions.md のみ生成し、Step 2.6 はスキップ

---

### Step 3: Create Feature Branch and Spec

1. プロジェクト名を `designs/README.md` セクション1 の「名称」フィールドから取得
2. short-name を名称から生成（2-4 words, kebab-case。例: "Smart Order Manager" → "smart-order-manager"）
3. 一行説明を feature description として使用
4. spec-kit のブランチ作成スクリプトを実行:

```bash
.specify/scripts/bash/create-new-feature.sh --json --short-name "[short-name]" "[一行説明]"
```

5. 出力された JSON から BRANCH_NAME と SPEC_FILE のパスを記録
6. スクリプトが存在しない場合のフォールバック: `mkdir -p specs/001-[short-name]` で手動作成

### Step 4: Generate spec.md

全 `designs/` ファイルを読み込み、spec-kit の `spec-template.md` 形式で `spec.md` を生成する。

#### Section Mapping

##### User Scenarios & Testing（必須）

**ソース:** `designs/user_stories.md`

変換ルール:
- US-001 → User Story 1、US-002 → User Story 2 ...
- 優先度: Must → P1, Should → P2, Could → P3
- `ストーリー` → User Story の説明文
- `受け入れ基準` → Acceptance Scenarios（Given-When-Then をそのまま維持）
- `ソースFR` → 「Why this priority」に FR の説明を要約して記載

```markdown
### User Story 1 - [US-001のタイトル] (Priority: P1)

[US-001のストーリー文を自然言語に変換]

**Why this priority**: [ソースFRの説明を要約 + 優先度の根拠]

**Screen Reference**: SCR-001 [Screen Name]
[designs/ui_design_brief.md Section 7 に SCR-XXX ↔ US-XXX マッピングがある場合のみ記載。
 マッピングがない場合や ui_design_brief.md が存在しない場合はこの行をスキップ]

**Independent Test**: [受け入れ基準の最初の項目を「〜で独立テスト可能」形式に]

**Acceptance Scenarios**:

1. **Given** [事前条件], **When** [アクション], **Then** [期待結果]
2. **Given** [代替条件], **When** [アクション], **Then** [期待結果]
```

##### Edge Cases

**ソース:** `designs/functional_requirements.md` の各 FR の例外フロー

- 全 FR の「例外フロー」を収集し、Edge Cases セクションに集約

##### Requirements > Functional Requirements（必須）

**ソース:** `designs/functional_requirements.md`

**重要:** spec-kit テンプレートでは `## Requirements` の子セクションとして `### Functional Requirements` が配置される。見出し階層を正確に守ること。

変換ルール:
- FR-001 の ID をそのまま維持
- 「説明」フィールドを "System MUST [capability]" 形式に変換
- Must 優先度の FR を spec.md の Functional Requirements に含める
- Should/Could 優先度の FR は Assumptions セクションに以下の形式で記載:
  ```
  - Future consideration: [FR の説明を自然言語に変換]（元 FR-XXX, Priority: Should）
  ```
  （FR ID をそのまま記載せず自然言語に変換する。spec-kit パーサーとの混同を防ぐため）
- [NEEDS CLARIFICATION] マーカー: 事前条件やビジネスルールに曖昧さがある場合に付与（最大3個。spec-kit テンプレートの推奨に準拠）。3個を超える場合は影響度の高い順に3個を選び、残りは合理的なデフォルトで解決する

```markdown
## Requirements

### Functional Requirements

- **FR-001**: System MUST [designs/functional_requirements.md FR-001 の説明を変換]
- **FR-002**: System MUST [同上]
```

##### Key Entities

**ソース:** `designs/ubiquitous_language.md`（存在する場合）

変換ルール:
- UL の用語をエンティティとして記載
- 定義とコンテキストを含める
- 存在しない場合: FR の「アクター」と「事後条件」に出現する名詞を抽出してエンティティ化

##### Success Criteria（必須）

**ソース:** `designs/README.md` セクション2「成功の定義」

変換ルール:
- 定量指標を SC-001 形式に変換
- 技術非依存・測定可能な表現に調整（実装詳細を含めない）

##### Assumptions

**ソース:** `designs/README.md` セクション5「制約・前提条件」+ `designs/non_functional_requirements.md`

変換ルール:
- 制約条件をAssumption形式に変換
- Should/Could 優先度の FR を「将来検討」として記載
- NFR の目標値を制約として記載

### Step 5: Quality Validation

spec.md 生成後、spec-kit の品質チェックリストを実行:

1. `.specify/templates/checklist-template.md` を参照し、`specs/[feature]/checklists/requirements.md` を生成
2. 以下を検証:
   - [ ] 実装詳細（言語、FW、API）が含まれていないこと
   - [ ] 全必須セクションが完了していること
   - [ ] FR が全てテスト可能で曖昧でないこと
   - [ ] 成功基準が測定可能で技術非依存であること
   - [ ] [NEEDS CLARIFICATION] が 3 個以下であること
   - [ ] FR のビジネスルールで、スキーマ/リンターで表現不可能なものが conventions.md Section 4 に記載されていること
   - [ ] 例: soft delete ポリシー、監査証跡パターン、マルチテナンシーアクセス制御、条件付きバリデーション
3. 不合格項目があれば spec.md / conventions.md を修正（最大3イテレーション）

### Step 6: Report Completion

```
✅ speckit-bridge 完了

📄 生成ファイル:
  .specify/memory/constitution.md  — プロジェクト原則 + Architecture Governance
  .specify/memory/conventions.md   — 命名規約・構造規約（50行以下）
  specs/[feature]/spec.md          — 統合仕様書
  specs/[feature]/checklists/      — 品質チェックリスト

🛡️ Anti-Drift 状況:
  conventions.md:           ✅ 生成済み（L1: Intent）
  ESLint naming-convention: [✅ 設定済み / ⚠️ ESLint未導入]（L2: Guard）
  eslint-plugin-boundaries: [✅ 設定済み / ⚠️ 未導入]（L2: Guard）
  Husky pre-commit:         [✅ 設定済み / ⚠️ 未導入]（L2: Guard）
  Business Rules:           [X]件 抽出（スキーマ外ルール）

📊 変換サマリー:
  FR: [X]件 → Functional Requirements
  US: [X]件 → User Scenarios
  NFR: [X]件 → Assumptions / Constraints
  UL: [X]件 → Key Entities
  SC: [X]件 → Success Criteria
  BR: [X]件 → Business Rules（conventions.md Section 4）

🔗 次のステップ:
  /speckit.plan   → 技術設計（plan.md, data-model.md, contracts/）
  /speckit.tasks  → タスク分解（tasks.md）
  /speckit.clarify → [NEEDS CLARIFICATION] の解決（該当がある場合）

💡 成長時の追加ツール（Phase B/C）:
  3つ目のエンティティ追加時 → plop.js（ファイル生成テンプレート）
  API外部公開時 → Spectral（OpenAPIリンター）+ prisma-lint
```

---

## Mapping Reference (Quick View)

| designs/ ファイル | spec-kit 出力先 | 変換内容 |
|---|---|---|
| `README.md` | `constitution.md` | 目的・原則・制約・成功指標 |
| `README.md` | `spec.md` Success Criteria | 成功の定義 → SC-001 形式 |
| `README.md` | `spec.md` Assumptions | 制約・前提条件 |
| `functional_requirements.md` | `spec.md` Functional Requirements | FR-001 → "System MUST" 形式 |
| `functional_requirements.md` | `spec.md` Edge Cases | 各 FR の例外フロー |
| `non_functional_requirements.md` | `spec.md` Assumptions | NFR 目標値を制約として |
| `non_functional_requirements.md` | `constitution.md` Quality Standards | 主要 NFR を品質基準に |
| `user_stories.md` | `spec.md` User Scenarios & Testing | US → User Story (P1/P2/P3) |
| `ubiquitous_language.md` | `spec.md` Key Entities | UL 用語 → エンティティ |
| `ubiquitous_language.md` | `conventions.md` Sections 1-5 | 命名規約・構造規約・スキーマ外ルール・トークン命名 |
| `ui_design_brief.md` | `spec.md` User Scenarios (Screen Reference) | SCR-XXX ↔ US-XXX マッピング |
| `ui_design_brief.md` | `constitution.md` Design Artifacts | Figma URL 参照 |
| DESIGN.md (root) | `conventions.md` Section 5 | トークン命名規約の継承 |
| DESIGN.md (root) | `constitution.md` Design Artifacts | HEAL/SYNC プロトコル参照 |

---

## Error Handling

| エラー | 対処 |
|--------|------|
| `designs/` が存在しない | `/requirements_designer` の実行を促す |
| `FR-001` が存在しない | Phase 2（機能要件の抽出）の完了を促す |
| `US-001` が存在しない | Phase 4B（ユーザーストーリー生成）の完了を促す |
| 品質スコア < 70 | 警告表示、ユーザー判断でオーバーライド可 |
| `specify` CLI が見つからない | `uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git@v0.4.3"` を案内（PyPI の `specify` は別パッケージなので注意） |
| `.specify/` が存在しない | `specify init --here --ai claude --force` を実行 |

---

## Language Support

- SKILL.md 自体は英語（Claude Code 規約）
- ユーザーへの出力（Step 6 レポート等）は日本語（CLAUDE.md の Communication ルールに従う）
- spec.md の言語ルール:
  - セクションヘッダ: **英語**（spec-kit テンプレート準拠。`## User Scenarios & Testing` 等）
  - FR/US/NFR の ID: **英語**（`FR-001`, `US-001` 等）
  - エンティティ名: **英語**（後続の `specify plan` が英語前提のため）
  - 説明文・ストーリー本文: **英語推奨**（後続コマンドの精度を維持するため。ユーザーが日本語を希望する場合は許容するが、`specify plan` の出力品質が下がる可能性を警告する）
