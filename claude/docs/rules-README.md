# ルール

## 構造

ルールは **共通** レイヤーと **言語別** ディレクトリで構成されています:

```
rules/
├── common/          # 言語非依存の原則（常にインストール）
│   ├── coding-style.md
│   ├── git-workflow.md
│   ├── testing.md
│   ├── performance.md
│   ├── patterns.md
│   ├── hooks.md
│   ├── agents.md
│   └── security.md
├── typescript/      # TypeScript/JavaScript 固有
├── python/          # Python 固有
├── golang/          # Go 固有
├── swift/           # Swift 固有
└── php/             # PHP 固有
```

- **common/** には言語非依存の普遍的な原則が含まれています（言語固有のコード例なし）
- **言語ディレクトリ** は共通ルールをフレームワーク固有のパターン、ツール、コード例で拡張します。各ファイルは対応する共通ファイルを参照します

## インストール

### 方法 1: インストールスクリプト（推奨）

```bash
# 共通 + 1つ以上の言語固有ルールセットをインストール
./install.sh typescript
./install.sh python
./install.sh golang
./install.sh swift
./install.sh php

# 複数言語を一度にインストール
./install.sh typescript python
```

### 方法 2: 手動インストール

> **重要:** ディレクトリ全体をコピーしてください。`/*` でフラット化しないでください。
> 共通ディレクトリと言語固有ディレクトリには同名のファイルがあります。
> フラット化すると言語固有ファイルが共通ルールを上書きし、
> 言語固有ファイルが使用する `../common/` の相対参照が壊れます。

```bash
# 共通ルールをインストール（全プロジェクトに必要）
cp -r rules/common ~/.claude/rules/common

# プロジェクトの技術スタックに基づいて言語固有ルールをインストール
cp -r rules/typescript ~/.claude/rules/typescript
cp -r rules/python ~/.claude/rules/python
cp -r rules/golang ~/.claude/rules/golang
cp -r rules/swift ~/.claude/rules/swift
cp -r rules/php ~/.claude/rules/php
```

## ルール vs スキル

- **ルール** は広く適用される標準、規約、チェックリストを定義します（例:「テストカバレッジ 80%」「ハードコードされたシークレット禁止」）
- **スキル**（`skills/` ディレクトリ）は特定タスク向けの詳細でアクション可能なリファレンスを提供します（例: `python-patterns`, `golang-testing`）

言語固有のルールファイルは適切な箇所で関連スキルを参照します。ルールは*何をすべきか*を、スキルは*どうやるか*を示します。

## 新しい言語の追加

新しい言語（例: `rust/`）のサポートを追加するには:

1. `rules/rust/` ディレクトリを作成
2. 共通ルールを拡張するファイルを追加:
   - `coding-style.md` — フォーマットツール、イディオム、エラーハンドリングパターン
   - `testing.md` — テストフレームワーク、カバレッジツール、テスト構成
   - `patterns.md` — 言語固有のデザインパターン
   - `hooks.md` — フォーマッター、リンター、型チェッカーの PostToolUse フック
   - `security.md` — シークレット管理、セキュリティスキャンツール
3. 各ファイルの先頭に以下を記載:
   ```
   > このファイルは [common/xxx.md](../common/xxx.md) を <言語> 固有の内容で拡張しています。
   ```
4. 利用可能なスキルがあれば参照し、なければ `skills/` に新しいスキルを作成

## ルールの優先順位

言語固有ルールと共通ルールが競合する場合、**言語固有ルールが優先** されます（具体的なものが一般的なものをオーバーライド）。これは CSS の詳細度や `.gitignore` の優先順位と同様の階層設定パターンです。

- `rules/common/` は全プロジェクトに適用される普遍的なデフォルトを定義
- `rules/golang/`, `rules/python/`, `rules/swift/`, `rules/php/`, `rules/typescript/` 等は言語のイディオムに合わせてデフォルトをオーバーライド

### 例

`common/coding-style.md` はデフォルト原則として不変性を推奨しています。言語固有の `golang/coding-style.md` はこれをオーバーライドできます:

> Go のイディオムではポインタレシーバによる構造体の変更が一般的です — 一般原則は [common/coding-style.md](../common/coding-style.md) を参照しつつ、Go のイディオムに沿った変更が優先されます。

### オーバーライド注記付きの共通ルール

言語固有ファイルによってオーバーライドされる可能性がある `rules/common/` のルールには以下の注記が付いています:

> **言語注記**: このルールは、このパターンがイディオムに合わない言語では言語固有ルールによってオーバーライドされる場合があります。
