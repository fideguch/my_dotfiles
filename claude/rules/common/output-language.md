# Output Language Policy

## Principle

ユーザー向けに生成するドキュメント・マークダウンファイルは、原則として**日本語**で記述する。

## Scope

### 日本語で書くもの（MUST）

| 対象 | 例 |
|------|-----|
| スキルが生成するファイル出力 | bochi-data/topics/, memos/, newspaper/ 等 |
| マークダウンの見出し・セクション名 | `## アイデア概要`, `## 調査結果`, `## 次のステップ` |
| ドキュメント本文・説明文 | レポート、分析結果、メモ、要件定義 |
| Notion ページの内容 | ページタイトル・本文・テーブル内容 |
| ユーザーへの説明・回答 | 会話テキスト全般 |

### 英語のままにするもの（MUST NOT translate）

| 対象 | 理由 |
|------|------|
| コード（変数名、コメント、docstring） | 国際的な可読性 |
| Git コミットメッセージ・PR 本文 | Conventional Commits 準拠 |
| 評価基準・スコアリング指標 | E-E-A-T, SCAMPER, OST 等の固有名詞・フレームワーク名 |
| テーブルのヘッダーキー（機械可読） | `E-E-A-T`, `Source`, `Feasibility` 等、データ処理に使われるカラム |
| JSONL / YAML のキー名 | `type`, `tags`, `status`, `freshness` 等 |
| CLI コマンド・ファイルパス | 技術的な正確性 |
| reference/ 内の評価ルーブリック | 翻訳による精度低下を防止 |

## Template Adaptation

スキルの reference/ に英語テンプレートがある場合、**ファイル出力時にセクション見出しを日本語に変換して使用する**。テンプレートファイル自体は変更しない。

### 変換例

| テンプレート（英語） | 出力時（日本語） |
|---------------------|----------------|
| `## Idea Overview` | `## アイデア概要` |
| `## Research Results` | `## 調査結果` |
| `## Critique Results` | `## 批評結果` |
| `## Opportunities` | `## 機会` |
| `## Solution Candidates` | `## ソリューション候補` |
| `## Minimum Experiments` | `## 最小限の実験` |
| `## User Hypotheses` | `## ユーザー仮説` |
| `## Requirements Summary` | `## 要件まとめ` |
| `## Next Steps` | `## 次のステップ` |
| `## Daily Brief` | `## デイリーブリーフ` |
| `## Categories & Articles` | `## カテゴリ別記事` |
| `## Content` | `## 内容` |
| `## Context` | `## コンテキスト` |
| `## Resolution` | `## 対応結果` |

## Hybrid Rule

フレームワーク固有名詞は原語のまま使い、説明は日本語にする：

```markdown
## SCAMPER 展開方向
- 選択した視点: Substitute（代替）
- 展開の詳細: ...

## 調査結果

### 高品質ソース (3件)
| # | タイトル | ソース | E-E-A-T | 要約 |
```

> **Language note**: This rule applies universally across all languages and project types.
