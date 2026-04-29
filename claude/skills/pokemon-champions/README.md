# pokemon-champions

Pokemon Champions シングル6vs3対戦の **廃人トレーナーモード** Claude Code スキル。
`/pokechamp` で発動するとセッション持続でガチ廃人ペルソナが起動し、ダメ計即時 / 構築アドバイス / 最新メタを 3-tier latency で提供する。

> **v0.2.0 (2026-04-30) 大規模拡張**
> - 14 ソース体制 (Tier S+/S/A/B/C 階層) 確立
> - YouTube 字幕全文取得 (youtube-transcript-api 統合)
> - X (Nitter RSS) アクセス確立
> - 公式 DB 採用率データを構築提案の必須根拠化
> - 実装/未実装アイテム SSOT 構築
> - Pokemon Champions 専用ナーフ反映
> - リモートエージェントで日次メタ自動取得

---

## できること

| 用途 | Tier | 想定レイテンシ | 出力 |
|---|---|---|---|
| ダメ計 (対面確認) | T1 | <300ms | 確定数 + 16通り乱数 + ASCIIバー |
| 構築アドバイス / サイクル設計 | T2 | 1-5秒 | 役割対象マトリクス + 並び案複数 |
| 最新メタ / 環境調査 | T3 | 5-30秒 | usage統計 + 動画字幕要約 + 鮮度マーク + 出典URL |

ペルソナは **ガチ廃人標準語・データ主導・図表ファースト・勝率最優先**。会話の中心ポケモン1体を選定し、応答末尾で `poke -n <英名>` を1回だけ呼んでターミナル背景を切替える (既存pokeコマンドへの依存)。

---

## 対応スコープ

- **対戦フォーマット**: シングル6vs3 のみ (ダブル/VGC/トリプル/ローテは non-goals)
- **メカニクス**: Gen 1-9 全世代 (テラスタル / ダイマックス / Z技 / メガ進化 / キョダイマックス 全対応、@smogon/calc 委譲)
- **Pokemon Champions 仕様**: テラス無し / 個体値V固定 / 持ち時間7分 / 時間切れ引き分け / メガ復活 / こだわり鉢巻・眼鏡・チョッキ未実装 など
- **ポケモン**: 1516体 (リージョン形態・パラドックス含む)
- **技**: 954技 / **特性**: 318 / **道具**: 583
- **日本語名**: 1221体 + 196形態

---

## 14 ソース体制 (v0.2.0)

T3 / MIXED 応答での情報源は **Tier 階層化** され、構築の数字根拠は DB 系 (Tier S+) を必須参照する。

### Tier S+ (構築の数字根拠・必須)

| URL | 種別 | 取得データ |
|-----|------|----------|
| `https://champs.pokedb.tokyo/pokemon/show/[ZZZZ-NN]?rule=0` | DB(JP) | 持ち物/技/性格/努力値の採用率% |
| `https://pokechamdb.com/en/pokemon/[name]?season=M-1&format=single` | DB(EN) | 同上、英名でクエリ |
| `https://yakkun.com/ch/` | 公式扱い | 実装/未実装、育成論、種族値 |

### Tier S (24h 鮮度の動向・廃人感覚)

| ハンドル | プラットフォーム | 取得手段 |
|---------|----------------|---------|
| くろこ (@Kuroko_965) | YouTube | RSS + 字幕 (youtube-transcript-api) |
| 今日ポケch. | YouTube | RSS + 字幕 |
| ポケソル (@pokesol) | YouTube | RSS + 字幕 |
| @KYOUPOKEch | X | Nitter RSS |
| @poketettei | X | Nitter RSS |
| @Sifu_pokePress | X | Nitter RSS |

### Tier A (補助・構築事例)

- `https://yakkun.com/bbs/party/list/?soft=4&rule=0&sort=rank` (yakkun BBS)
- `note.com` 検索 (24-72h 以内の構築記事)
- `https://www.smogon.com/forums/threads/pokemon-champions-bss-viability-rankings.3780943/`

### Tier B (二次まとめ・裏取り)

- Game8 / Altema / GameWith / Gamerch

詳細: [references/authoritative_sources.md](references/authoritative_sources.md)

---

## 使い方

```
あなた:    /pokechamp
廃人:      ガチ環境モード起動した。
           データ: pokedex 1516 / moves 954 / abilities 318。Showdown commit pinned。
           ダメ計: bin/pokechamp-calc (T1 wall-clock 中央値 ~180ms / 予算 300ms)。
           何聞きたい？対面?選出?ダメ計?今期トップ?

あなた:    今期環境のガブの主流型を教えて
廃人:      [T3: champs.pokedb + pokechamdb 並列 fetch → 持ち物40.5%タスキ等の数値根拠]

あなた:    ガブ軸でサイクル組みたい
廃人:      [T2: 役割対象マトリクス + 並び案 + 採用理由言語化]

あなた:    /pokechamp off
廃人:      モード解除。
```

---

## アーキテクチャ

```
~/.claude/skills/pokemon-champions/
├── SKILL.md                     # ペルソナ起動指示 + T1/T2/T3 ルーター
│                                  + HARD-GATE 実装確認 + 14ソース参照規則
├── README.md                    # 本ファイル
├── bin/pokechamp-calc           # Bun単一バイナリ (@smogon/calc ラップ、59MB)
├── data/                        # Showdown data (commit pinned)
│   ├── pokedex.json (488KB)
│   ├── moves.json (260KB)
│   ├── abilities.json (30KB)
│   ├── items.json (78KB)
│   ├── learnsets.json (3.2MB)
│   ├── ja_names.json (312KB)
│   └── stats/                   # Smogon usage stats
├── lib/                         # Pythonランタイム
│   ├── lookup.py
│   ├── intent_router.py
│   ├── visualizer.py
│   ├── persona.py
│   ├── session_state.py
│   └── meta_fetcher.py
├── scripts/
│   ├── extract_data.ts
│   ├── calc_wrapper.ts
│   ├── build_calc.sh
│   ├── fetch_yt_transcript.py   # ★v0.2.0 YouTube 字幕取得
│   └── update_meta.sh
├── tests/
├── cache/
│   ├── session.json
│   ├── meta_*.json              # T3 鮮度命層キャッシュ
│   ├── yt_transcripts/          # ★v0.2.0 動画字幕アーカイブ
│   │   └── YYYY-MM-DD/*.txt
│   ├── usage_stats/             # ★v0.2.0 DB 採用率キャッシュ
│   │   └── YYYY-MM-DD/[pokemon].json
│   ├── daily_meta/              # ★v0.2.0 日次メタスナップショット
│   └── daily_reports/           # ★v0.2.0 リモートエージェント生成レポート
└── references/                  # 廃人spec集 + プロトコル
    ├── pokemon_champions_rules.md  # PCルール
    ├── damage_formula.md           # @smogon/calc準拠
    ├── modern_team_building.md     # 現代構築論
    ├── role_theory.md              # 役割理論
    ├── meta_glossary.md            # 廃人用語集
    ├── persona_guide.md            # ペルソナ運用
    ├── authoritative_sources.md    # ★v0.2.0 14ソース Tier 階層
    ├── data_extraction_guide.md    # ★v0.2.0 各DBのデータ抽出レシピ
    ├── implementation_status.md    # ★v0.2.0 実装/未実装 SSOT
    ├── realtime_access_methods.md  # ★v0.2.0 X/YouTube アクセス
    └── build_proposal_protocol.md  # ★v0.2.0 構築提案チェックリスト
```

---

## v0.2.0 主要追加機能

### 1. YouTube 字幕全文取得

```bash
python3 scripts/fetch_yt_transcript.py <video_url> ja
```

`youtube-transcript-api` (pure Python) で字幕テキスト全取得。10分動画 ~1万字。
サブエージェントで要約させて構築論に反映。

### 2. X (Nitter RSS) アクセス

```
https://nitter.net/<user>/rss
```

WebFetch で直接取得可能。X API 認証不要。

### 3. DB 採用率を構築の必須根拠に

すべての構築提案前に **champs.pokedb.tokyo + pokechamdb.com の採用率%** を取得し、
30%+ の選択を主流扱い、未満はマイナー扱いとして明示。

詳細: [references/build_proposal_protocol.md](references/build_proposal_protocol.md)

### 4. 実装/未実装 SSOT

Pokemon Champions 専用の未実装アイテム/技/特性を明文化。誤って未実装持ち物を提案しない。

```
未実装持ち物: ゴツゴツメット / 鉢巻 / 眼鏡 / いのちのたま /
              突撃チョッキ / 厚底ブーツ / 弱点保険 / レッドカード / イバンの実
```

詳細: [references/implementation_status.md](references/implementation_status.md)

### 5. リモートエージェントで日次メタ自動取得

毎朝 7:00 JST に Anthropic クラウドのリモートエージェントが起動し:

1. 14 ソースから最新データ取得
2. 前日との差分検出
3. 新規動画字幕を全部抽出
4. 構築微調整提案を生成
5. `cache/daily_reports/YYYY-MM-DD.md` に保存 → git push
6. 重大変動時は GitHub Issue 自動オープン

ローカル受け取りは `cd ~/my_dotfiles && git pull` で完結。

---

## データ戦略 (3-tier latency + 鮮度三層)

### Tier別

| Tier | データ | レイテンシ | ソース |
|---|---|---|---|
| **T1 即時** | ダメ計・種族値・タイプ・技性能・特性・道具 | <300ms | ローカル (Showdown同梱) |
| **T2 研究** | 構築・サイクル・選出 | 1-5秒 | T1 + ローカル思考 |
| **T3 最新** | 上位構築・使用率・型・立ち回り対策・メタ | 5-30秒 | 14 ソース並列 fetch |

### 鮮度別 (v0.2.0 で 3 層化)

| 層 | 内容 | TTL | 鮮度マーク |
|---|---|---|---|
| **スピード層** | ダメ計式・種族値・タイプ・技・特性・道具 | 1ヶ月 | 不要 |
| **構築数字層 (S+)** | 持ち物/技/性格/努力値の採用率 | **24時間** | 必須 |
| **動向層 (S)** | 配信者動画・X 投稿・新興構築 | **24時間** | 必須 |

T3 応答は必ず `fetched_at` と `source_url` を引用。

---

## セットアップ

### 前提

- macOS (Bun + Python3 必須)
- 既存 `poke` コマンド (オプション、応答末尾の背景連動用)

### 初期化

```bash
# 1. 依存ツール確認
which bun python3 git
# 不在なら: brew install bun

# 2. スキルクローン (or my_dotfiles 経由で symlink)
SKILL_ROOT=~/.claude/skills/pokemon-champions
ls $SKILL_ROOT/SKILL.md

# 3. データ取得 + calc binary ビルド (約2-3分)
cd $SKILL_ROOT/scripts
bun install
bun run extract_data.ts
bash build_calc.sh

# 4. v0.2.0 追加: youtube-transcript-api インストール
pip3 install --user youtube-transcript-api

# 5. 動作確認
bash -c 'echo "{\"gen\":9,\"attacker\":{\"name\":\"Garchomp\",\"item\":\"Choice Band\",\"nature\":\"Jolly\",\"evs\":{\"atk\":252,\"spe\":252}},\"defender\":{\"name\":\"Mimikyu\",\"evs\":{\"hp\":4}},\"move\":{\"name\":\"Earthquake\"}}' | $SKILL_ROOT/bin/pokechamp-calc
# 期待: 117-138% guaranteed OHKO

python3 $SKILL_ROOT/scripts/fetch_yt_transcript.py "https://www.youtube.com/watch?v=ej2RqEWGUig" ja | head -5
# 期待: クロコ氏動画の字幕冒頭が出る
```

---

## 品質保証

本スキルは以下のゲートを通過済み:

- ✅ **forge_ace v4.0** (5-Agent Quality Gate)
- ✅ **gatekeeper v1.2.1** (HG-1〜HG-5)
- ✅ **Type B Gate 3** (E2E)
- ✅ **Plan Quality Gate** (planner opus)

### テスト

```bash
# Pythonユニット (31件)
python3 ~/.claude/skills/pokemon-champions/tests/test_lib.py

# Calc fixtures (10件、T1 latency計測込み)
cd ~/.claude/skills/pokemon-champions/scripts && bun run_fixtures.ts
```

---

## 関連ナレッジ (再利用可能)

このスキル開発で得た**汎用ナレッジ**は bochi メモに切り出し済み:

- `~/.claude/bochi-data/memos/2026-04-30-youtube-x-access-methods.md` - YouTube/X アクセス手法 (任意のスキルで転用可)

---

## 設計方針

### 持続型ペルソナ

`/pokechamp` 発動 → セッション終了 or `/pokechamp off` までガチ廃人モード継続。

### 公式扱いソースの優先

ユーザー指定の **yakkun.com/ch/** は「公式扱い」として実装/未実装の SSOT に。
**champs.pokedb.tokyo + pokechamdb.com** の採用率データを構築提案の必須根拠とする。
動画情報は **「なぜ流行っているか」の補完専用**、構築の数字根拠としては Tier S+ 未満。

詳細: [references/build_proposal_protocol.md](references/build_proposal_protocol.md)

---

## ライセンス・出典

- **@smogon/calc** (MIT) — ダメ計エンジン
- **smogon/pokemon-showdown** (MIT) — データソース
- **PokeAPI CSV data** (BSD 3-Clause) — 日本語名
- **Smogon Stats** — 鮮度命層 usage統計
- **youtube-transcript-api** (MIT) — YouTube 字幕取得 (v0.2.0+)
- **champs.pokedb.tokyo / pokechamdb.com / yakkun.com/ch/** — Pokemon Champions 専用採用率 DB

---

## バージョン

- **v0.2.0 (2026-04-30)** — 14 ソース体制 / YouTube 字幕統合 / DB 採用率必須化 / 実装SSOT / 日次自動エージェント
- v0.1.0 (2026-04-29) — 初回リリース、forge_ace + gatekeeper SHIP_WITH_CONDITIONS
