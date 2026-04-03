# forge_ace v4.0

**5-Agent Quality Gate for Code and Text**

コードだけでなく、仕様書・プロンプト・設定ファイルまで含めた変更を、5つの専門エージェントが多層的に検証する品質ゲートシステム。

---

## ミッション

> 「コードが動く」と「正しいものが作られた」のギャップを埋める。

ソフトウェア開発では、コードのコンパイルやテスト通過だけでは品質を保証できない。要件との整合性、仕様書間の一貫性、UIの視覚的品質、そしてプロダクトビジョンとの方向性 -- これらすべてを体系的に検証するために forge_ace は設計された。

### なぜ必要か

| 問題 | 従来の対策 | forge_ace の対策 |
|------|-----------|-----------------|
| AIが生成したコードに脆弱性が2.74倍多い (CodeRabbit 2025) | 人間によるコードレビュー | Guardian による自動リスク分析 + 8軸品質評価 |
| 仕様書を書いただけで実装済みと誤認する | チェックリスト | Type B ゲート: 振る舞い証拠を必須化 |
| UIの実装がデザインから乖離する | デザインレビュー会議 | Designer による自動スクリーンショット + 25項目QA |
| 要件と実装のドリフトが検出されない | PM手動レビュー | Overseer による要件分解 + ドリフト検出 |

---

## アーキテクチャ

```
                          ユーザー要件
                              |
                    [Step 1] Session Init
                    分類: Tier (Standard/Full)
                          Type (A: コード / B: テキスト)
                              |
                    [Step 2] Dispatch Checkpoint
                    ユーザー確認 (HARD-GATE)
                              |
                    [Step 3] Plan Quality Gate
                    GAFA基準の計画品質検証
                              |
                    [Step 4] Writer --------+
                    TDD + Red Team          |
                    Type B: 再現→差分証拠    |
                              |             |
                    [Step 5] Guardian       |
                    爆発半径 + 8軸評価       |
                    Type B: 整合性検証       |
                              |             |
                    [Step 6] Overseer       |
                    要件一致 + ドリフト検出   |
                              |             |
                    [Step 7] PM-Admin       |  [Step 8] Designer
                    スコープ + bochi記憶     |  スクリーンショット
                              |             |  25項目QA
                              +------+------+
                                     |
                           [Step 9] Complete
                           Type B: E2E実行指令
```

### セッションタイプ

| タイプ | エージェント構成 | 用途 |
|--------|----------------|------|
| **Standard** | Writer -> Guardian -> Overseer(std) -> PM-Admin(std) | コードのみ、UIなし |
| **Full** | Writer -> Guardian -> Overseer(full) -> PM-Admin(full) + Designer | UI/UX変更あり |
| **Design Session** | PM-Admin -> Designer -> 相互レビュー | UI/UXのみ |

---

## コアコンセプト

### Type A と Type B

forge_ace の最大の特徴は、変更対象を2つのタイプに分類し、それぞれに最適な検証戦略を適用すること。

| | Type A (コード) | Type B (テキスト) |
|---|----------------|------------------|
| **対象** | `.ts`, `.py`, `.go`, `.rs` 等 | `.md`, `.yaml`, `.json`, SKILL.md, プロンプト |
| **検証手段** | テスト実行、型チェック、Bash証拠 | 再現→差分→E2E振る舞い証拠 |
| **Writer** | RED-GREEN TDD | Reproduce-Before-Fix + Delta Demonstration |
| **Guardian** | 爆発半径 + 8軸評価 | 構造レビュー + 「振る舞い検証不可」フラグ |
| **最終ゲート** | テスト全通過 | E2E Execution Mandate |

### Evidence-of-Execution (実行証拠)

全エージェントに適用される鉄則:

- **Bash実行出力** が唯一の証拠
- 「テストが通るはず」「問題ないと思う」は証拠ではない
- Guardian は Writer の報告を信用せず、自らテストを再実行する
- Type B では、ファイル内容の変更ではなく**振る舞いの変化**が証拠

### 12のアンチパターン

過去のインシデントから抽出された構造的失敗パターン。全エージェントが検出・防止する:

| # | パターン | 概要 |
|---|---------|------|
| 1 | Spec-as-Done Illusion | 仕様書 = 実装済みと誤認 |
| 2 | Phantom Addition Fallacy | 既存のものを「追加」と計画 |
| 3 | Delegated Verification Deficit | 他エージェントの報告を鵜呑み |
| 4 | Delta Thinking Trap | 差分思考で品質を過大評価 |
| 5 | Stale Context Divergence | 古い行番号・記憶を参照 |
| 6 | Spec-without-Implementation-Table | 外部依存の実装状況が不明 |
| 7 | Precondition-as-Assumption | テストの前提条件が未検証 |
| 8 | High-Risk-Implementation-Gap | セッション外作業が未確認 |
| 9 | Disconnected-Bloodline | 接続先の到達性が未検証 |
| 10 | Deployment-Sync Blindness | gitパスと実行時パスの乖離 |
| 11 | Spec-Layer Blindness | テキスト修正を完了と誤認 |
| 12 | Agent-Skip Rationalization | エージェントが勝手にフロー縮小 |

---

## 5つのエージェント

### Writer

**役割**: 変更の実装  
**モデル**: Sonnet (複数ファイルはOpus)  
**主要フェーズ**:
1. **Comprehension** -- 対象ファイルの完全読解、High-Risk スキャン
2. **Test First (RED)** -- 失敗するテストを先に書く
3. **Implementation (GREEN)** -- テストを通す最小実装
4. **30% Check** -- エッジケース、セキュリティ、統合、並行性
5. **Red Team Self-Attack** -- 入力ファジング、状態破壊、依存障害、権限昇格
6. **Self-Review** -- 要件マッピング、スコープ逸脱チェック

### Guardian

**役割**: 構造的安全性の検証  
**モデル**: Opus  
**主要フェーズ**:
1. **VP-1 独立検証** -- Writer の報告を信用せず自ら確認
2. **リスクティア分類** -- LOW / MEDIUM / HIGH
3. **爆発半径分析** -- インポーター追跡、型契約、設定、副作用
4. **AIコード欠陥スキャン** -- 幻の依存、前提条件、API鮮度、過剰設計、OWASP
5. **接続性 + デプロイ同期** -- サーバー間到達性、gitパス = 実行時パス
6. **8軸品質評価** -- 設計、機能、複雑性、テスト、セキュリティ、文書、性能、自動化

### Overseer

**役割**: 要件との整合性検証  
**モデル**: Opus  
**主要フェーズ**:
1. **要件分解** -- テスト可能な主張に分解
2. **実装検証 (HARD-GATE)** -- コードを直接読み、各要件の実装を確認
3. **Type B 振る舞い検証** -- 再現証拠 + 差分の説得力評価 + E2Eシナリオ定義
4. **ドリフト検出** -- スコープクリープ、不足、誤解、ビジョン整合、振る舞い変化
5. **制度的知識** [Full] -- コーディング規約、過去の失敗との照合
6. **DESIGN.md検証** [Full] -- トークン、階層、HEAL プロトコル

### PM-Admin

**役割**: プロダクト品質ゲート  
**モデル**: Opus  
**主要フェーズ**:
1. **bochi記憶ロード** -- 判断パターン、ユーザープロファイル、成功率による校正
2. **スコープ遵守 (HARD-GATE)** -- 「全部任せる」「ここまで作って」「設計だけ見て」
3. **ランタイム検証 (HARD-GATE)** -- テストを自ら実行、Type B検証チェーン完全性
4. **E2E実行指令** [Type B] -- 全エージェント承認後もE2Eシナリオ実行を義務化

### Designer

**役割**: UI/UX品質レビュー (Full tier のみ)  
**モデル**: Sonnet (複雑なUXはOpus)  
**主要フェーズ**:
1. **スクリーンショット取得** -- Playwright で3ビューポート (デスクトップ/モバイル/タブレット)
2. **25項目QAチェックリスト** -- レイアウト、タイポグラフィ、ナビゲーション、ビジュアル、アクセシビリティ、パフォーマンス
3. **AI視覚判定** -- DESIGN.md との比較、差異検出
4. **DESIGN.md準拠** -- トークン、コンポーネント階層、HEAL プロトコル

---

## 品質基準

### 8軸評価

| # | 軸 | 基準 |
|---|---|------|
| 1 | 設計とアーキテクチャ | ISO 25010: 保守性 |
| 2 | 機能と正確性 | ISO 25010: 機能適合性 |
| 3 | 複雑性と可読性 | Google eng-practices |
| 4 | テストと信頼性 | ISO 25010 + CISQ |
| 5 | セキュリティ | ISO 25010 + CISQ |
| 6 | ドキュメントとユーザビリティ | ISO 25010: ユーザビリティ |
| 7 | パフォーマンスと効率 | ISO 25010: 性能効率 |
| 8 | 自動化と自己改善 | forge_ace + DORA 2025 |

### 出荷基準

- **合格ライン**: 70/80 (87.5%)
- **必須条件**: CRITICAL: 0 | HIGH: 0

---

## ステートマシン

セッション状態は `/tmp/.forge-ace-session.json` で管理:

```
INIT -> CLASSIFIED -> CHECKPOINT_FILLED -> USER_CONFIRMED
  -> WRITER_DISPATCHED -> WRITER_DONE
  -> GUARDIAN_DISPATCHED -> GUARDIAN_DONE
  -> OVERSEER_DISPATCHED -> OVERSEER_DONE
  -> PM_ADMIN_DISPATCHED -> PM_ADMIN_DONE
  -> [DESIGNER_DISPATCHED -> DESIGNER_DONE]  (Full のみ)
  -> COMPLETE
```

各遷移はタイムスタンプ付きで記録される。ディスパッチフックが不正な状態遷移を防止する。

---

## コスト見積もり

| Tier | エージェント数 | 入力トークン | 出力トークン | 推定コスト | 推定時間 |
|------|-------------|------------|------------|-----------|---------|
| Standard | 4 | 20K-35K | 10K-18K | ~$1-3 | ~8-12分 |
| Full | 5 | 30K-50K | 15K-25K | ~$3-8 | ~15-25分 |

---

## ファイル構成

```
~/.claude/skills/forge_ace/
|
|-- README.md                     <- 本ファイル
|-- README.en.md                  <- 英語版
|-- SKILL.md                      <- オーケストレーションプロトコル
|
|-- writer-prompt.md              <- Writer エージェントプロンプト
|-- guardian-prompt.md            <- Guardian エージェントプロンプト
|-- overseer-prompt.md            <- Overseer エージェントプロンプト
|-- pm-admin-prompt.md            <- PM-Admin エージェントプロンプト
|-- designer-prompt.md            <- Designer エージェントプロンプト
|
|-- anti-patterns.md              <- 12パターン参照カード
|-- plan-quality-rubric.md        <- GAFA計画品質ルーブリック
|-- quality-standards.md          -> bochi-data/master-quality-review.md
|
|-- references/
|   |-- origin-and-sources.md     <- ミッション、研究ソース、トークン見積もり
|   |-- evidence-rules.md         <- Evidence-of-Execution 共有ルール
|   |-- type-b-gates.md           <- Type B 変更検証ゲート
|   `-- type-b-pqg.md            <- Type B 計画品質チェックリスト
|
|-- checklists/
|   |-- ai-defect-scan.md         <- Guardian Phase 2.5
|   |-- connectivity-check.md     <- Guardian Phase 2.7
|   `-- cross-document-integrity.md <- Guardian Phase 2 Type B
|
|-- tests/
|   |-- test-dispatch-guard.sh    <- ディスパッチガードフックテスト (14ケース)
|   `-- test-state-machine.sh     <- ステートマシンテスト (12ケース)
|
`-- test-scenarios/
    |-- scenario-s-small-change.md        <- S: ドキュメント修正 (Standard)
    |-- scenario-m-api-change.md          <- M: APIエンドポイント追加 (Standard)
    |-- scenario-m-type-b-spec-fix.md     <- M: 仕様書修正 (Type B)
    `-- scenario-l-fullstack-with-ui.md   <- L: フルスタック + UI (Full)
```

---

## 研究基盤

| # | ソース | 適用箇所 |
|---|--------|---------|
| 1 | Anthropic Multi-Agent Research | モデル選択、並列化 |
| 2 | Addy Osmani (Google Chrome) | 3-5エージェント最適、worktree隔離 |
| 3 | Microsoft Azure AI Orchestration | Sequential + Maker-Checker パターン |
| 4 | Amazon 90-day Code Reset (2026-03) | Guardian Tier-1 思考 |
| 5 | Glen Rhodes Blast Radius | レビュー負荷増大、VP-1 |
| 6 | Propel Code Guardrails | 3段階リスクルーティング |
| 7 | CodeRabbit 2025 | AIコードの脆弱性2.74倍 |
| 8 | Baymard Institute UX | 207ヒューリスティック -> 25項目 |
| 9 | Deloitte Decision AI | 品質チェックポイント、監査証跡 |
| 10 | Prompt Engineering 2026 | XMLタグ +23%、thinking -40%幻覚 |
| 11 | DORA 2025 Report | AIレビュー +42-48% バグ検出 |
| 12 | Kinde Spec Drift | 振る舞いドリフト != データドリフト |

---

## トラブルシューティング

| 状況 | 対処 |
|------|------|
| GUARDIAN_ESCALATE (Round 3) | 要件を明確化して再分割、または手動判断 |
| Designer がスクリーンショットを取得できない | Playwright未インストール -> Manual Screenshot Fallback |
| Type B で全エージェント承認後にE2E失敗 | E2E Mandate の設計通り: revert to REJECTED |
| Writer が NEEDS_CONTEXT を返す | スコープ定義を見直し、不足ファイルを追加 |
| ステートマシンが不正遷移 | `/tmp/.forge-ace-session.json` を確認、ディスパッチフックのログを調査 |

---

## バージョン履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| v4.0 | 2026-04-01 | Hook物理強制 + ステートマシン + プロンプト圧縮(-43%) |
| v3.1 | 2026-03-30 | Type A/B分類 + E2Eゲート |
| v2.0 | 2026-03-29 | Plan Quality Gate + bochi統合 |
| v1.2 | 2026-03-28 | 5エージェント体制確立 |

---

## ライセンス

Private skill -- 個人利用。
