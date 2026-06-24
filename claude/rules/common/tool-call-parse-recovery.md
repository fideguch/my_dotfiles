# Tool-Call Parse Failure — Avoidance & Recovery

> 横断ルール。Claude Code 全体で頻発する
> `The model's tool call could not be parsed (retry also failed).`
> （= ツール呼び出しが parse 不能になりターンが強制停止する）への
> 恒久的な回避・復旧方針を定義する。

## 症状 (Symptom)

ツール呼び出し（`Edit` / `Write` / `Bash` など）の最中に、以下のいずれかで
ターンが途中停止する：

- `The model's tool call could not be parsed (retry also failed).`
- `Your tool call was malformed and could not be parsed. Please retry.`
- ツール引数の直前に `count` / `court` 等の余分なトークンが混入する
- `<invoke>` 等のマークアップが「実行されず」プレーンテキストとして出力される
- `stop_reason: tool_use` なのに `tool_use` ブロックが本文に存在しない

## 根本原因 (Root Cause — 検証済み)

モデル側のシリアライズ回帰。`tool_use` を構造化 JSON ではなく
「壊れた XML 風テキスト」として出力し、ハーネスが parse 不能になる。
内部の自動リトライは同一コンテキストを再生するため同じく失敗する
（= "retry also failed"）。**クライアント/設定側のバグではない。**

- **Opus 4.8（特に 1M context 版）で多発**。Opus 4.7 はほぼ無傷、
  Sonnet 4.6 は影響なし（issue で「4.7 に切替で即解決」と確認）。
- **1M context ＋ extended thinking（effortLevel: xhigh）＋ 高トークン密度** が
  最悪の組合せ。コンテキストが膨らむほどストリーミングが断片化し再現率が上がる。
- 公式 issue（anthropics/claude-code）: #63604 / #60584（"court"/"count" 混入）/
  #64418 / #63583 / #64658 / #63875 / #62123。多くが open（model 側）。

## 永続設定 (Configured — settings.json)

このルールと併せて以下を恒久設定済み（公式に文書化されたレバーのみ使用）：

| Key | 旧 | 新 | 根拠 |
|-----|----|----|------|
| `model` | `opus[1m]` | `opus` | 最頻発要因の **1M context** を除去。Opus 4.8 の品質は維持（200K でも十分広い） |
| `effortLevel` | `xhigh` | `high` | 1M と相互作用する **extended thinking** の負荷を低減 |

> `CLAUDE_CODE_DISABLE_1M_CONTEXT` / `CLAUDE_CODE_AUTO_COMPACT_WINDOW` は
> コミュニティ報告のみで **公式設定ドキュメントに存在しない**（動作保証なし）。
> 採用しない。1M を切るなら公式の `model` 変更で行う。

## 回避ガイドライン (For Claude — トリガー確率を下げる)

- **Edit は小さく原子的に**。巨大な `old_string` / `new_string` を 1 回の `Edit` に
  詰めない。大規模な書換えは 1 個の巨大 Edit より **`Write` で全置換** する。
- ツール引数に巨大なバイナリ/異常な制御文字を不必要に埋め込まない。
- **コンテキストが大きくなったらフェーズ境界で `/compact`** を提案・実行する。
- **同一のツール呼び出しを盲目的に再送しない**。内部リトライ済みで失敗しているため、
  同じ引数の再送は同じ結果になる。引数を分割・縮小してから再試行する。

## 復旧プロトコル (For User — ターン停止後の手順)

このエラーはターンを停止させるため、復旧は**ユーザー操作**が起点になる。
段階的に：

1. **同じ文面で再送しない**。要求を分割するか言い換えて再依頼する
   （例: 巨大な 1 編集 → 複数の小編集に分ける）。
2. `/compact` でコンテキストを圧縮 → 「続きを実行して」と依頼。
3. 改善しなければ `/clear` で新規コンテキスト、または**新セッション開始**。
   malformed なターンを含む session を `--resume` すると再発しやすい。
4. 最終手段: `/model` で一時的に **sonnet（影響なし）** か **opus 4.7** に切替えて
   当該タスクを完了させる。
5. Claude Code を最新へ更新（parser/信頼性の改善が changelog で随時入る）。

## 出典 (Sources)

- 公式設定/env: https://code.claude.com/docs/en/settings
- GitHub issues: anthropics/claude-code #63604, #60584, #64418, #63583,
  #64658, #63875, #62123

> **Language note**: This rule applies universally across all languages and project types.
