# フック

フックは Claude Code のツール実行前後に発火するイベント駆動型の自動化機能です。コード品質の担保、ミスの早期検出、定型チェックの自動化を行います。

## フックの仕組み

```
ユーザーリクエスト → Claude がツールを選択 → PreToolUse フック実行 → ツール実行 → PostToolUse フック実行
```

- **PreToolUse** フック: ツール実行前に動作。ブロック（終了コード 2）または警告（stderr 出力）が可能
- **PostToolUse** フック: ツール実行後に動作。出力の分析は可能だがブロックはできない
- **Stop** フック: Claude の各レスポンス後に動作
- **SessionStart/SessionEnd** フック: セッションのライフサイクル境界で動作
- **PreCompact** フック: コンテキスト圧縮前に動作。状態の保存に使用

## このプラグインのフック

### PreToolUse フック

| フック | マッチャー | 動作 | 終了コード |
|--------|-----------|------|-----------|
| **開発サーバーブロッカー** | `Bash` | tmux 外での `npm run dev` 等をブロック — ログアクセスを確保 | 2 (ブロック) |
| **tmux リマインダー** | `Bash` | 長時間コマンド（npm test, cargo build, docker）に tmux を提案 | 0 (警告) |
| **Git push リマインダー** | `Bash` | `git push` 前に変更のレビューをリマインド | 0 (警告) |
| **ドキュメントファイル警告** | `Write` | 非標準の `.md`/`.txt` ファイルについて警告（README, CLAUDE, CONTRIBUTING, CHANGELOG, LICENSE, SKILL, docs/, skills/ は許可） | 0 (警告) |
| **戦略的コンパクト** | `Edit\|Write` | 約50ツールコールごとに手動 `/compact` を提案 | 0 (警告) |
| **InsAIts セキュリティ監視 (オプトイン)** | `Bash\|Write\|Edit\|MultiEdit` | 高シグナルなツール入力のセキュリティスキャン。`ECC_ENABLE_INSAITS=1` 設定時のみ有効。`pip install insa-its` が必要 | 2 (重大時ブロック) / 0 (警告) |

### PostToolUse フック

| フック | マッチャー | 動作 |
|--------|-----------|------|
| **PR ロガー** | `Bash` | `gh pr create` 後に PR URL とレビューコマンドをログ |
| **ビルド分析** | `Bash` | ビルドコマンド後のバックグラウンド分析（非同期、非ブロック） |
| **品質ゲート** | `Edit\|Write\|MultiEdit` | 編集後の高速品質チェック |
| **Prettier フォーマット** | `Edit` | 編集後に JS/TS ファイルを Prettier で自動フォーマット |
| **TypeScript チェック** | `Edit` | `.ts`/`.tsx` ファイル編集後に `tsc --noEmit` を実行 |
| **console.log 警告** | `Edit` | 編集ファイル内の `console.log` について警告 |

### ライフサイクルフック

| フック | イベント | 動作 |
|--------|---------|------|
| **セッション開始** | `SessionStart` | 前回のコンテキスト読み込みとパッケージマネージャー検出 |
| **プリコンパクト** | `PreCompact` | コンテキスト圧縮前に状態を保存 |
| **console.log 監査** | `Stop` | 各レスポンス後に変更ファイルの `console.log` をチェック |
| **セッションサマリー** | `Stop` | トランスクリプトパスが利用可能な場合にセッション状態を永続化 |
| **パターン抽出** | `Stop` | セッションから抽出可能なパターンを評価（継続学習） |
| **コストトラッカー** | `Stop` | 軽量な実行コストのテレメトリマーカーを出力 |
| **セッション終了マーカー** | `SessionEnd` | ライフサイクルマーカーとクリーンアップログ |

## フックのカスタマイズ

### フックの無効化

`hooks.json` のフックエントリを削除またはコメントアウトしてください。プラグインとしてインストールされている場合は、`~/.claude/settings.json` でオーバーライドできます:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [],
        "description": "オーバーライド: すべての .md ファイル作成を許可"
      }
    ]
  }
}
```

### ランタイムフック制御（推奨）

`hooks.json` を編集せずに環境変数でフックの動作を制御できます:

```bash
# minimal | standard | strict (デフォルト: standard)
export ECC_HOOK_PROFILE=standard

# 特定のフック ID を無効化（カンマ区切り）
export ECC_DISABLED_HOOKS="pre:bash:tmux-reminder,post:edit:typecheck"
```

プロファイル:
- `minimal` — 必須のライフサイクルと安全フックのみ
- `standard` — デフォルト。品質と安全のバランス型チェック
- `strict` — 追加のリマインダーと厳格なガードレールを有効化

### 独自フックの作成

フックはツール入力を JSON として stdin で受け取り、JSON を stdout に出力するシェルコマンドです。

**基本構造:**

```javascript
// my-hook.js
let data = '';
process.stdin.on('data', chunk => data += chunk);
process.stdin.on('end', () => {
  const input = JSON.parse(data);

  // ツール情報へのアクセス
  const toolName = input.tool_name;        // "Edit", "Bash", "Write" 等
  const toolInput = input.tool_input;      // ツール固有のパラメータ
  const toolOutput = input.tool_output;    // PostToolUse でのみ利用可能

  // 警告（非ブロック）: stderr に出力
  console.error('[Hook] 警告メッセージ');

  // ブロック（PreToolUse のみ）: 終了コード 2
  // process.exit(2);

  // 常にオリジナルデータを stdout に出力
  console.log(data);
});
```

**終了コード:**
- `0` — 成功（実行を継続）
- `2` — ツールコールをブロック（PreToolUse のみ）
- その他の非ゼロ — エラー（ログに記録されるがブロックしない）

### フック入力スキーマ

```typescript
interface HookInput {
  tool_name: string;          // "Bash", "Edit", "Write", "Read" 等
  tool_input: {
    command?: string;         // Bash: 実行されるコマンド
    file_path?: string;       // Edit/Write/Read: 対象ファイル
    old_string?: string;      // Edit: 置換元テキスト
    new_string?: string;      // Edit: 置換先テキスト
    content?: string;         // Write: ファイル内容
  };
  tool_output?: {             // PostToolUse のみ
    output?: string;          // コマンド/ツールの出力
  };
}
```

### 非同期フック

メインフローをブロックすべきでないフック（バックグラウンド分析など）:

```json
{
  "type": "command",
  "command": "node my-slow-hook.js",
  "async": true,
  "timeout": 30
}
```

非同期フックはバックグラウンドで実行されます。ツール実行をブロックすることはできません。

## よくあるフックレシピ

### TODO コメントの警告

```json
{
  "matcher": "Edit",
  "hooks": [{
    "type": "command",
    "command": "node -e \"let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const i=JSON.parse(d);const ns=i.tool_input?.new_string||'';if(/TODO|FIXME|HACK/.test(ns)){console.error('[Hook] TODO/FIXME が追加されました - Issue の作成を検討してください')}console.log(d)})\""
  }],
  "description": "TODO/FIXME コメント追加時に警告"
}
```

### 大きなファイルの作成をブロック

```json
{
  "matcher": "Write",
  "hooks": [{
    "type": "command",
    "command": "node -e \"let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const i=JSON.parse(d);const c=i.tool_input?.content||'';const lines=c.split('\\n').length;if(lines>800){console.error('[Hook] ブロック: ファイルが800行を超えています ('+lines+'行)');console.error('[Hook] より小さく焦点を絞ったモジュールに分割してください');process.exit(2)}console.log(d)})\""
  }],
  "description": "800行を超えるファイルの作成をブロック"
}
```

### Python ファイルを ruff で自動フォーマット

```json
{
  "matcher": "Edit",
  "hooks": [{
    "type": "command",
    "command": "node -e \"let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const i=JSON.parse(d);const p=i.tool_input?.file_path||'';if(/\\.py$/.test(p)){const{execFileSync}=require('child_process');try{execFileSync('ruff',['format',p],{stdio:'pipe'})}catch(e){}}console.log(d)})\""
  }],
  "description": "編集後に Python ファイルを ruff でフォーマット"
}
```

### 新しいソースファイルにテストファイルを要求

```json
{
  "matcher": "Write",
  "hooks": [{
    "type": "command",
    "command": "node -e \"const fs=require('fs');let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const i=JSON.parse(d);const p=i.tool_input?.file_path||'';if(/src\\/.*\\.(ts|js)$/.test(p)&&!/\\.test\\.|\\.spec\\./.test(p)){const testPath=p.replace(/\\.(ts|js)$/,'.test.$1');if(!fs.existsSync(testPath)){console.error('[Hook] テストファイルが見つかりません: '+p);console.error('[Hook] 期待されるパス: '+testPath);console.error('[Hook] 先にテストを書くことを検討してください (/tdd)')}}console.log(d)})\""
  }],
  "description": "新しいソースファイル追加時にテスト作成をリマインド"
}
```

## クロスプラットフォームについて

フックロジックは Windows, macOS, Linux で動作するよう Node.js スクリプトで実装されています。一部のシェルラッパーは継続学習オブザーバーフック用に残されていますが、プロファイルゲートされており Windows セーフなフォールバック動作があります。

## 関連ファイル

- [rules/common/hooks.md](../rules/common/hooks.md) — フックアーキテクチャガイドライン
- [skills/strategic-compact/](../skills/strategic-compact/) — 戦略的コンパクションスキル
- [scripts/hooks/](../scripts/hooks/) — フックスクリプトの実装
