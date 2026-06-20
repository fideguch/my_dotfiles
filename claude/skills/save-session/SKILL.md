---
name: save-session
description: セッション終了時に、プロジェクトの memory ディレクトリへ「引き継ぎ(Handoff)」メモを書き出し、MEMORY.md インデックスを更新し、次セッション用のコピペ起動プロンプトを生成する。並行セッションのメモリを破壊しない（per-project + per-session-id 名前空間 / append-not-overwrite）。
origin: project
triggers: ["save session", "save-session", "handoff", "hand off", "wrap up session", "save and quit", "セッションを保存", "引き継ぎ", "ハンドオフ", "保存して終了", "ここまでを記録", "記録して", "セッションをまとめて", "次のセッションに引き継いで", "このセッションを保存"]
version: 1.0.0
metadata:
  type: project
  node_type: skill
---

# Save Session Skill

> セッションの状態を「次の自分（または別エージェント）が cold-start で即座に動ける」**typed handoff** として永続化する。
> 会話履歴の自動圧縮（`/compact`）とは別物。これは**意図して構造化された引き継ぎファイル**である。
> 出力本文は日本語、ID/パス/コミット文・frontmatter キーは英語（ユーザー言語ポリシー準拠）。

## When to use

- ユーザーが上記 triggers のいずれかを発話したとき。
- タスク境界（機能完了 / デバッグ解決 / 計画フェーズ完了）に達したとき。**コンテキストが 50–75% 埋まる前に proactive に**実行する（context rot 予防）。
- 長時間セッションの一区切り、または別マシン/別エージェントへ作業を渡すとき。
- **使わない場面**: 単発の質問、些末な1行修正（重い handoff はオーバーヘッド）。`CLAUDE.md` に書くべき恒久ルールはここに書かない（後述の二層分離）。

## How It Works（process flow）

1. **読者を定義する（bird's-eye first）** — このメモを最初に読むのは「記憶ゼロの次セッション」。冒頭に「誰が読むか / 何のプロジェクトか / なぜ重要か」の俯瞰を必ず置く。
2. **HARD-GATE capture checklist を全項目埋める**（下記）。空欄・`[TODO: …]` プレースホルダが残るなら finalize しない。
3. **session-id と branch を解決**してファイル名を組む（anti-collision protocol）。
4. **Handoff memory ファイルを per-project memory dir に書く**（既存を上書きせず append/新規）。
5. **MEMORY.md インデックスへ1行追記**（既存行は削除しない）。
6. **コピペ用 handoff プロンプトを生成**して会話に出力する。

---

## <HARD-GATE id="capture-checklist">必須キャプチャ項目（全項目必須・推測で埋めない）

このセッションから**実際に得られた事実のみ**を、形容詞でなく**値・コマンド・パス**で記録する。1項目でも未確定なら「未確定」と明記し、捏造しない。

```
[ ] G1  WHY / プロジェクト重要性  : このセッションの【最初のユーザープロンプト】の意図を verbatim-in-spirit で1〜2文に保存。なぜこの作業が重要か。
[ ] G2  Bird's-eye / 読者         : 「誰が読むか（記憶ゼロの次セッション）/ どのプロジェクト / 現在地」の俯瞰3行。
[ ] G3  Current state             : 直前に何を能動的に作業していたか。完了%・動いているもの。
[ ] G4  Decisions + rationale     : 各決定を「決定 + 理由（なぜそうしたか）」で。理由なしは禁止（最重要原則）。
[ ] G5  Next steps（actionable）   : 次に取るべき具体的な first action を1つ以上。曖昧なゴールでなく即実行可能な手順。
[ ] G6  Open questions / blockers : 未解決事項。再現手順 or 選択肢を併記（例: 「鍵が admin-scoped → rotate / re-scope / accept」）。
[ ] G7  Key files / file map      : 変更/重要ファイルを【絶対パス + 役割】で。可能なら行番号。複製でなく参照。
[ ] G8  Gotchas / do-not          : 詰まり所・既知の罠・【試したが失敗した/スコープ外のアプローチ】。次セッションの再失敗を防ぐ最重要フィールド。
[ ] G9  Deploy / release state    : ブランチ、最新コミット、ビルド/テスト結果（値で: 例「lint 0 error / build OK」）、本番反映状況、env var の状態。
```

> 品質ゲート: G1–G9 のいずれかが空 / シークレット混入 / `[TODO: …]` 残存 のいずれかなら **finalize 拒否**。verbose なスタックトレースやツール出力の丸ごと貼り付けは禁止（rot 加速）— 要約とパス参照で。

---

## Output / File Format

### ファイルパス（per-project memory dir）

```
~/.claude/projects/<project-slug>/memory/handoff_<branch>_<YYYY-MM-DD>_<session-short>.md
```

- `<project-slug>` = cwd をスラッシュ→ハイフン変換したもの（例: `-Users-fumito-ideguchi-Desktop-start-work-medicavice-medicaviceLP`）。`ls ~/.claude/projects/` で実在ディレクトリを確認してから使う。
- `<branch>` = `git rev-parse --abbrev-ref HEAD`（スラッシュは `-` に置換）。
- `<session-short>` = `$CLAUDE_SESSION_ID` 先頭8文字。未設定なら transcript dir 名の UUID 先頭8文字、それも無ければ `date +%H%M%S`（衝突回避のため必ず一意化）。

### ファイル本文テンプレート（user frontmatter schema 準拠）

```markdown
---
name: Handoff <branch> <YYYY-MM-DD>
description: <1行サマリ。何をしていて次に何をするか>
metadata:
  node_type: memory
  type: project
  originSessionId: <full session UUID or fallback>
---

> 🦅 **誰が読む / 俯瞰**: <G2 — 記憶ゼロの次セッション向けの現在地3行>
> **status**: active | blocked | done | stale  ・  **branch**: <branch>  ・  **更新**: <YYYY-MM-DD HH:MM>

## なぜこの作業か（WHY / 重要性）
<G1 — 最初のユーザープロンプトの意図 + なぜ重要か>

## 現在の状態（Current State）
<G3 — 直前の作業 / 完了% / 動いているもの>

## 決定と理由（Decisions + Rationale）
- **<決定>** — 理由: <なぜ>

## 次のステップ（Next Steps）
1. <即実行可能な first action>

## 未解決・ブロッカー（Open Questions / Blockers）
- <未解決 + 再現手順 or 選択肢>

## 重要ファイル（Key Files / Map）
- `<絶対パス>` — <役割>（行番号があれば :Ln）

## 罠・やらないこと（Gotchas / Do-Not）
- ⚠️ <既知の罠 / 試して失敗したアプローチ — 次セッションで再試行しない>

## デプロイ/リリース状態（Deploy / Release）
- branch=<branch> / last commit=<sha 短縮 + subject>
- build/lint/test=<値で>  ・  本番反映=<yes/no + URL>  ・  env=<設定状況>

## Handoff Chain
- 前: <predecessor handoff filename or none>
```

### MEMORY.md インデックス更新（既存形式に1行 append）

既存 MEMORY.md の bullet を**1行も削除せず**、末尾に追記する（書式は既存に厳密一致）:

```markdown
- [Handoff <branch> <YYYY-MM-DD>](handoff_<branch>_<date>_<session-short>.md) — <1行サマリ> (status: active, session <short>)
```

---

## <step id="anti-collision">Anti-Collision Protocol（並行セッション安全性）

並行セッションが互いのメモリを**破壊しない**ための HARD ルール:

1. **per-project + per-session-id 名前空間**: ファイル名に branch・date・session-short を必ず含める。同一トピックでも session-short が異なれば別ファイル。**他セッションの handoff ファイルを上書き・編集しない**。
2. **append-don't-overwrite**: MEMORY.md は read→append のみ。既存行の削除/書き換えは禁止。書き込み前に必ず最新を Read してから1行追記する（lost-update 回避）。
3. **1 active handoff per branch+topic**: 同じ branch+topic の handoff が既にあれば、新規作成でなく**同一セッションのファイルのみ**更新可。別セッション由来なら触らず新規を作る。
4. **branch をメタに pin**: `branch:` を frontmatter 直後の行に固定。resume 側はこれを検証し cross-branch drift を防ぐ。
5. **status を lifecycle flag** として運用: `active`/`blocked`/`done`/`stale`。完了・放棄した handoff は速やかに `done`/`stale` に更新し、並行エージェントが死んだ状態を live と誤認しないようにする。
6. **恒久ルールはここに書かない**: 「システムが何であるか」= `CLAUDE.md`/memory の常設ファイル。「今回何が起きたか」= この handoff。混在させない（mutable state を branch ごとに分離することが clobbering 防止の本質）。

---

## 次セッション用コピペ起動プロンプト（生成して会話に出力）

finalize 後、以下を**そのままコピペできる形**で会話末尾に出力する（`<...>` は実値に置換）:

```text
前回の引き継ぎから再開してください（ゼロから再起動しないこと）。

1. まず引き継ぎファイルを読む（コードに触れる前に）:
   ~/.claude/projects/<project-slug>/memory/handoff_<branch>_<date>_<session-short>.md
2. あなたの理解を3行で要約してから始める。再起動でなく「続き」として進める。
3. status と branch を検証: status=active かつ現在の git branch=<branch> を確認できるまでツールを実行しない（pre-flight gate）。stale/不一致なら停止して報告。
4. 「次のステップ」の最初の項目から着手する。不明点は最小限だけ質問する。

このプロジェクトの WHY: <G1 の1文>
直近のブロッカー: <G6 の要点 or なし>
```

---

## Forbidden（違反条件）

- ❌ G1–G9 のいずれかを推測・捏造で埋める / 空のまま finalize する。
- ❌ 他セッション（異なる session-short）の handoff ファイルを上書き・編集する。
- ❌ MEMORY.md の既存行を削除・改変する（append のみ許可）。
- ❌ 決定の「理由」を省く / 値でなく形容詞（"動く" "直した"）で記述する。
- ❌ 失敗したアプローチ（Do-Not）を省略する。
- ❌ verbose なツール出力・スタックトレースを丸ごと貼る（要約 + パス参照に）。
- ❌ 恒久ルールを handoff に、セッション固有状態を CLAUDE.md に、と層を取り違える。
- ❌ シークレット（API キー・トークン・env 値）を本文に書く。

## Related

- 恒久メモリ: `~/.claude/projects/<project-slug>/memory/MEMORY.md` + topic files
- 言語ポリシー: `~/.claude/rules/common/output-language.md`（JA 本文 / EN コード・ID）
- 並行作業規律: `~/.claude/rules/common/planning-verification.md`（Stale Context Divergence 回避）

> 出典統合（2024-2026 リサーチ）: Cline memory-bank の activeContext/progress 二層 · robertguss 9-section handoff · Continuous-Claude の YAML frontmatter + status table · agent-toolkit の typed-state 品質ゲート · ai-memory の "where you left off" prepend · 「why / do-not / next-step / file-map を必ず捕捉」という業界共通則。
