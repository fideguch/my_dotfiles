# pokemon-champions

Pokemon Champions シングル6vs3対戦の **廃人トレーナーモード** Claude Code スキル。
`/pokechamp` で発動するとセッション持続でガチ廃人ペルソナが起動し、ダメ計即時 / 構築アドバイス / 最新メタを 3-tier latency で提供する。

## できること

| 用途 | Tier | 想定レイテンシ | 出力 |
|---|---|---|---|
| ダメ計 (対面確認) | T1 | <300ms | 確定数 + 16通り乱数 + ASCIIバー |
| 構築アドバイス / サイクル設計 | T2 | 1-5秒 | 役割対象マトリクス + 並び案複数 |
| 最新メタ / 環境調査 | T3 | 5-30秒 | usage統計 + 鮮度マーク + 出典URL |

ペルソナは **ガチ廃人標準語・データ主導・図表ファースト・勝率最優先**。会話の中心ポケモン1体を選定し、応答末尾で `poke -n <英名>` を1回だけ呼んでターミナル背景を切替える (既存pokeコマンドへの依存)。

## 対応スコープ

- **対戦フォーマット**: シングル6vs3 のみ (ダブル/VGC/トリプル/ローテは non-goals)
- **メカニクス**: Gen 1-9 全世代 (テラスタル / ダイマックス / Z技 / メガ進化 / キョダイマックス 全対応、@smogon/calc 委譲)
- **ポケモン**: 1516体 (リージョン形態・パラドックス含む)
- **技**: 954技 / **特性**: 318 / **道具**: 583
- **日本語名**: 1221体 + 196形態 (PokeAPI 公式翻訳 + Showdown翻訳)

## 使い方

```
あなた:    /pokechamp
廃人:      ガチ環境モード起動した。
           データ: pokedex 1516 / moves 954 / abilities 318。Showdown commit pinned。
           ダメ計: bin/pokechamp-calc (T1 wall-clock 中央値 ~180ms / 予算 300ms)。
           何聞きたい？対面?選出?ダメ計?今期トップ?

あなた:    鉢巻ガブのEQでミミ確定？
廃人:      ## ダメ計: ガブリアス → ミミッキュ
           | 指標 | 値 |
           |---|---|
           | 最小 | 117.1% (295) |
           | 最大 | 138.1% (348) |
           | 確定 | guaranteed OHKO |
           ```
           0%   50%   100%  150%  200%
           [·······················████             ]
                117.1-138.1%
           ```
           → 1Hで沈むからミミ初手は危ない。テラ電気で透かしてくる前提で動け。

あなた:    ガブ軸でサイクル組みたい
廃人:      [T2: 役割対象マトリクス + 並び案 + 採用理由言語化]

あなた:    今期OUのTOP10は？
廃人:      [T3: usage統計 + 鮮度マーク "📅 最終更新: 2026-04-26 / Smogon Gen9OU" + 出典URL]

あなた:    /pokechamp off
廃人:      モード解除。
```

## アーキテクチャ

```
~/.claude/skills/pokemon-champions/
├── SKILL.md                     # ペルソナ起動指示 + T1/T2/T3 ルーター + 図表原則
├── bin/pokechamp-calc           # Bun単一バイナリ (@smogon/calc 0.11.0 ラップ、59MB)
│                                  ※ scripts/setup.sh でビルド (gitignore対象)
├── data/                        # Showdown data (commit 808f8584 pinned)
│   ├── pokedex.json (488KB)     # 1516体
│   ├── moves.json (260KB)       # 954技
│   ├── abilities.json (30KB)
│   ├── items.json (78KB)
│   ├── learnsets.json (3.2MB)
│   ├── typechart.json
│   ├── natures.json
│   ├── ja_names.json (312KB)    # 日英名マッピング
│   ├── VERSION.json             # SSOT pin情報
│   └── stats/                   # Smogon usage stats (鮮度命層、6h TTL)
├── lib/                         # Pythonランタイム
│   ├── lookup.py                # 日英/部分一致 → 内部ID解決
│   ├── intent_router.py         # T1/T2/T3キーワード分類
│   ├── visualizer.py            # ダメ計table / 役割マトリクス / 横棒グラフ
│   ├── persona.py               # 廃人用語40語 GLOSSARY
│   ├── session_state.py         # 会話継続state
│   └── meta_fetcher.py          # WebFetch + 6h cache + stale fallback
├── scripts/
│   ├── setup.sh                 # 初回セットアップ (data取得 + calc binary build)
│   ├── extract_data.ts          # Showdown TS → JSON 抽出
│   ├── calc_wrapper.ts          # stdin/stdout JSON I/O
│   ├── build_calc.sh            # bun build --compile
│   ├── run_fixtures.ts          # 10 fixture 精度検証 + T1 latency計測
│   ├── update_meta.sh           # 鮮度命層更新
│   └── parse_usage.py           # Smogon stats parser
├── tests/                       # 31 unit + 10 calc fixtures
└── references/                  # 廃人spec集
    ├── pokemon_champions_rules.md  # PCルール (公式情報未確定 markerあり)
    ├── damage_formula.md           # @smogon/calc準拠 SSOT宣言
    ├── modern_team_building.md     # 現代構築論 (動画概念インストール、出典URL+access date)
    ├── role_theory.md              # 古典×現代役割理論
    ├── meta_glossary.md            # 廃人用語集
    └── persona_guide.md            # 廃人↔標準対応表40語 + 5発話サンプル + NG表現
```

## データ戦略 (3-tier latency + 鮮度二層)

### Tier別

| Tier | データ | レイテンシ | ソース |
|---|---|---|---|
| **T1 即時** | ダメ計・種族値・タイプ・技性能・特性・道具 | <300ms | ローカル (Showdown同梱) |
| **T2 研究** | 構築・サイクル・選出 | 1-5秒 | T1 + ローカル思考 |
| **T3 最新** | 上位構築・使用率・型・立ち回り対策・メタ | 5-30秒 | WebFetch (Smogon stats / ポケ徹) + 6h cache |

### 鮮度別

| 層 | 内容 | TTL | 鮮度マーク |
|---|---|---|---|
| **スピード層** | ダメ計式・種族値・タイプ・技・特性・道具 | 1ヶ月 | 不要 (枯れた知識) |
| **鮮度命層** | 上位構築・使用率・採用率・型・立ち回り | **6時間** | **必須** (タイムスタンプ + 出典URL) |

## セットアップ

### 前提

- macOS (Bun + Python3 必須)
- 既存 `poke` コマンド (https://github.com/fideguch/my_dotfiles `.my_commands/poke`) — オプション、応答末尾の背景連動用

### 初期化

```bash
# 1. 依存ツール確認
which bun python3 git
# 不在なら:
brew install bun
# Python3 は pyenv/system 何でも可

# 2. スキルクローン (or my_dotfiles 経由で symlink)
SKILL_ROOT=~/.claude/skills/pokemon-champions
ls $SKILL_ROOT/SKILL.md  # 存在確認

# 3. データ取得 + calc binary ビルド (約2-3分、ネット必要)
cd $SKILL_ROOT/scripts
bun install
bun run extract_data.ts        # Showdown shallow clone + JSON抽出
bash build_calc.sh             # bun build --compile → bin/pokechamp-calc (59MB)

# 4. 動作確認
bash -c 'echo "{\"gen\":9,\"attacker\":{\"name\":\"Garchomp\",\"item\":\"Choice Band\",\"nature\":\"Jolly\",\"evs\":{\"atk\":252,\"spe\":252}},\"defender\":{\"name\":\"Mimikyu\",\"evs\":{\"hp\":4}},\"move\":{\"name\":\"Earthquake\"}}" | $SKILL_ROOT/bin/pokechamp-calc'
# 期待: 117-138% guaranteed OHKO
```

### 鮮度命層の更新 (任意、推奨6h cron)

```bash
bash $SKILL_ROOT/scripts/update_meta.sh
```

launchctl で6時間ごとの自動更新を仕込みたい場合は別途 plist を作成。

## 品質保証

本スキルは以下のゲートを通過済み:

- ✅ **forge_ace v4.0** (5-Agent Quality Gate): Writer / Guardian / Overseer / PM-Admin
- ✅ **gatekeeper v1.2.1** (HG-1〜HG-5): 仕様徹底確認・実機検証・推測修正禁止
- ✅ **Type B Gate 3** (E2E): 5/5 シナリオ PASS
- ✅ **Plan Quality Gate** (planner opus): GAFA 10軸評価

### テスト

```bash
# Pythonユニット (31件)
python3 ~/.claude/skills/pokemon-champions/tests/test_lib.py

# Calc fixtures (10件、T1 latency計測込み)
cd ~/.claude/skills/pokemon-champions/scripts && bun run_fixtures.ts
```

期待: 全PASS / T1 wall-clock 中央値 <300ms

## 既知の制約

| 項目 | 状態 | 影響度 |
|---|---|---|
| Pokemon Champions 公式 URL/レギュレーション | 未確定 (公式アナウンス待ち、`_PENDING` マーカー) | 低 (graceful fallback) |
| Form名英名フォールバック | 295件 (リージョン形態の一部) JP未マッチ | 低 (英名+注釈表示で動作) |
| Smogon stats月次更新 | cron未自動化 | 低 (手動 `update_meta.sh` で対応可) |
| 公式ルール変更時のデータ更新 | 手動 (`extract_data.ts` 再実行) | 中 (アプデ通知に追従が必要) |

## 設計方針

### 持続型ペルソナ (Persistence)

`/pokechamp` 発動 → セッション終了 or `/pokechamp off` までガチ廃人モード継続。会話文脈を保持し、「さっきの計算」「もっと受け足したい」等の参照解決に対応。

### 既存 `poke` との完全独立 (Decoupling)

- 既存 `~/my_dotfiles/.my_commands/poke*` は **改変なし**
- スキルは独立したデータ・ロジックを持つ
- 連携は出力末尾で `poke -n <英名>` を1回呼び出すのみ (オプショナル)

### 現代構築論ベース (Modern Team Building)

参考動画: 「【ガチ勢が解説】ポケモンの構築の種類、ちゃんと理解してる…？？」(2026-04 公開)
参考note: ポケモンチャンピオンズ：マスター到達までに遊んだ構築と考え方

- 古典的分類 (対面/サイクル/受けループ/バランス) は実戦では融合
- 採用理由言語化が最優先 (「強いから」じゃなく「何の役割か」)
- 環境最適に型を可変、採用理由は不変
- 使用率上位ポケに2体以上の対応駒を確保

詳細: `references/modern_team_building.md`

## ライセンス・出典

- **@smogon/calc** (MIT, https://github.com/smogon/damage-calc) — ダメ計エンジン
- **smogon/pokemon-showdown** (MIT, https://github.com/smogon/pokemon-showdown) — データソース (commit 808f8584 pinned)
- **PokeAPI CSV data** (BSD 3-Clause) — 日本語名 (1221件)
- **Smogon Stats** (https://www.smogon.com/stats/) — 鮮度命層 usage統計

## バージョン

- v0.1.0 (2026-04-29) — 初回リリース、forge_ace + gatekeeper SHIP_WITH_CONDITIONS
