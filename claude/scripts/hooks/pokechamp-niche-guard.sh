#!/bin/bash
# pokechamp-niche-guard.sh — UserPromptSubmit hook
#
# /pokechamp 起動中のセッションで niche 妨害技 (挑発/トリック/道連れ等) を
# ユーザーが質問した時、TOP30 打ち切り違反を未然に警告する。
#
# 関連 HG: SKILL.md §13 HARD-GATE: niche-depth ranking 必須 (v0.5.4)
# 関連 SCRIPT: ~/.claude/skills/pokemon-champions/scripts/fetch_niche_users.py

set -uo pipefail

# stdin から JSON を読む。失敗時は環境変数フォールバック。
INPUT_JSON="$(cat 2>/dev/null || true)"
PROMPT=""
if [ -n "$INPUT_JSON" ]; then
  PROMPT="$(printf '%s' "$INPUT_JSON" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get("prompt", "") or d.get("user_prompt", ""))
except Exception:
    pass
' 2>/dev/null)"
fi
if [ -z "$PROMPT" ]; then
  PROMPT="${CLAUDE_USER_PROMPT:-}"
fi

# Empty prompt → 何もしない (sub-agent dispatch 等)
[ -z "$PROMPT" ] && exit 0

# /pokechamp セッションのアクティブ判定 (cache 内 session.json で起動状況確認)
SESSION_FILE="$HOME/.claude/skills/pokemon-champions/cache/session.json"
POKECHAMP_ACTIVE=0
if [ -f "$SESSION_FILE" ]; then
  if grep -q '"active"\s*:\s*true' "$SESSION_FILE" 2>/dev/null; then
    POKECHAMP_ACTIVE=1
  fi
fi
# プロンプト自体に /pokechamp 系 keyword があれば常時 active 扱い
if printf '%s' "$PROMPT" | grep -qE 'pokechamp|ポケモン|構築|対面|ダメ計|ダメージ計算|ガブリアス|メガゲンガー|エルフーン|ヤミラミ|採用率|使用率|挑発|ちょうはつ|トリック|道連れ|アンコール|コットンガード|おきみやげ|こうそくスピン|どくびし|キノコのほうし|ねむりごな|あくびのうた|さいみんじゅつ|ふくろだたき|いやしのねがい|みかづきのまい'; then
  POKECHAMP_ACTIVE=1
fi

[ "$POKECHAMP_ACTIVE" -ne 1 ] && exit 0

# niche keyword 検出
NICHE_RE='(ちょうはつ|挑発|トリック|すりかえ|みちづれ|道連れ|アンコール|コットンガード|おきみやげ|こうそくスピン|どくびし|ステルスロック|キノコのほうし|ねむりごな|あくびのうた|あくびループ|さいみんじゅつ|ふくろだたき|いやしのねがい|みかづきのまい)'
DETECTED="$(printf '%s' "$PROMPT" | grep -oE "$NICHE_RE" | sort -u | tr '\n' ',' | sed 's/,$//')"

[ -z "$DETECTED" ] && exit 0

# 警告メッセージを stdout に出力 (Claude が context に embed する)
cat <<EOF

=== [POKECHAMP-NICHE-GUARD] HG-niche-depth applies ===

検出された niche keyword: $DETECTED

ユーザーは niche 妨害技に関する質問をしている。SKILL.md §13 HARD-GATE
「niche-depth ranking 必須」(v0.5.4) に従い、以下を遵守せよ:

1. TOP30 で打ち切るな。Tier S+ 3 サイト (champs.pokedb / pokechamdb / yakkun)
   のみ使用、game8 / altema / gamewith は禁止。
2. 必ず以下を Bash で実行 (頭の中の知識で済ませるな):

     python3 ~/.claude/skills/pokemon-champions/scripts/fetch_niche_users.py "<検出技>"

   出力の「掲載 ○」行 = 採用率 ≥5% の真の主犯候補。
3. 「掲載 ○」 のポケに対し、出力末尾の WebFetch URL list を順次 fetch して
   実数 % を取得し、表形式で提示する。
4. 「いたずらごころ / ばけのかわ / マジックミラー / どくよけ」等で
   先制 / 無効化 / 設置できるポケは脅威度上位として明示する。

違反例:
  ❌ TOP30 圏内 4 体だけ列挙して結論
  ❌ 「使用率低 = メタ影響なし」と推論
  ❌ Tier 外サイト (game8 等) で済ませる

正例:
  ✓ scripts/fetch_niche_users.py 出力 + 全「掲載 ○」を WebFetch + 実数 % 表

=== [POKECHAMP-NICHE-GUARD END] ===

EOF

exit 0
