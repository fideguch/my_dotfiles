# Pokemon Champions データ抽出ガイド

> **目的**: 各データソースから必要な情報を効率的に取り出すレシピ集。
> 構築提案の前に必ずこのプロトコルで数字を取得する。

---

## 1. champs.pokedb.tokyo (Tier S+)

### 全体使用率 TOP30 取得

```
URL  : https://champs.pokedb.tokyo/pokemon/list?rule=0
WebFetch Prompt:
  "Pokemon Champions シングル使用率TOP30を抽出。
   各ポケモン名と現在の順位を表形式で。最終更新日時も明記。"
```

### 個別ポケの型データ取得

```
URL  : https://champs.pokedb.tokyo/pokemon/show/[図鑑番号4桁]-[フォーム2桁]?rule=0
例   : ガブリアス → /pokemon/show/0445-00?rule=0
       メガガブ   → /pokemon/show/0445-50?rule=0

WebFetch Prompt:
  "[ポケモン名]の構築データを完全抽出。
   - 持ち物採用率TOP3 (各%)
   - 特性採用率
   - 性格採用率
   - 技採用率TOP6 (各%)
   - 努力値分布の上位パターン
   - 集計期間"
```

### 図鑑番号早見表 (主要ポケ)

| 名前 | 図鑑番号 | フォーム |
|------|---------|---------|
| リザードン | 0006 | 00 (通常) / 50 (メガY) / 51 (メガX) |
| フシギバナ | 0003 | 00 / 50 |
| ゲンガー | 0094 | 00 / 50 |
| カイリュー | 0149 | 00 / 50 (メガ) |
| ガブリアス | 0445 | 00 / 50 |
| カバルドン | 0450 | 00 |
| アーマーガア | 1004 | 00 |
| アシレーヌ | 0730 | 00 |
| ミミッキュ | 0778 | 00 |
| ブラッキー | 0197 | 00 |
| サザンドラ | 0635 | 00 |
| ミミロップ | 0428 | 00 / 50 |
| ハッサム | 0212 | 00 / 50 |
| ガチグマ アカツキ | 0901 | 10 (要確認) |
| マスカーニャ | 0908 | 00 |
| キラフロル | 0970 | 00 / 50 |
| ハバタクカミ | 0987 | 00 |

### 環境変動グラフ

```
URL  : https://champs.pokedb.tokyo/pokemon/chart
注意 : 動的レンダリングの可能性、取れない場合スキップ
```

---

## 2. pokechamdb.com (Tier S+ 補強)

### 全体使用率

```
URL  : https://pokechamdb.com/en?view=pokemon
WebFetch Prompt:
  "Pokemon Champions singles top 20 usage rankings,
   each Pokémon's current rank and last_updated timestamp."
```

### 個別ポケの型データ

```
URL  : https://pokechamdb.com/en/pokemon/[英名小文字]?season=M-1&format=single
例   : https://pokechamdb.com/en/pokemon/garchomp?season=M-1&format=single

WebFetch Prompt:
  "[Pokémon name]'s detailed Champions singles data:
   - Usage rank and %
   - Items adoption % (top 5)
   - Abilities %
   - Natures %
   - Moves adoption % (top 6)
   - EV spread top patterns
   - Last updated timestamp"
```

### 英名対応表 (champs.pokedb と異なる場合あり)

| 日本語 | 英名 | 注意 |
|--------|------|------|
| ガブリアス | garchomp | |
| アシレーヌ | primarina | |
| リザードン | charizard | |
| アーマーガア | corviknight | |
| カバルドン | hippowdon | |
| ゲンガー | gengar | |
| カイリュー | dragonite | |
| ギルガルド | aegislash | |
| ハッサム | scizor | |
| マスカーニャ | meowscarada | |
| ガチグマ | ursaluna | アカツキは `ursaluna-bloodmoon` |
| ミミッキュ | mimikyu | |
| ミミロップ | lopunny | |
| ブラッキー | umbreon | |
| サザンドラ | hydreigon | |
| ハバタクカミ | flutter-mane | |
| キラフロル | glimmora | |
| ヌメルゴン | goodra | |

---

## 3. yakkun.com/ch/ (Tier S+ 公式扱い)

### サイト構成

```
https://yakkun.com/ch/                ← TOP
https://yakkun.com/ch/zukan/n[番号]   ← ポケ図鑑（種族値・技・特性）
https://yakkun.com/ch/theory/p[番号]  ← 育成論
https://yakkun.com/ch/ranking.htm     ← 使用率
https://yakkun.com/ch/changes.htm     ← SV からの変更点
https://yakkun.com/ch/items.htm       ← 持ち物実装一覧
https://yakkun.com/ch/rule.htm        ← 公式ルール
```

### WebFetch が 403 で取れない場合

```
WebSearch Prompt:
  "site:yakkun.com/ch/ [取得したい情報]"
  例: "site:yakkun.com/ch/ ガブリアス 育成論"
```

### 図鑑番号 = champs.pokedb と共通（4桁ゼロ埋めなし）

例: ガブリアス = `n445` (yakkun) / `0445-00` (champs.pokedb)

---

## 4. YouTube 動画字幕 (Tier S 動向)

### 字幕全文取得

```bash
python3 ~/.claude/skills/pokemon-champions/scripts/fetch_yt_transcript.py <url> ja
# 例: python3 .../fetch_yt_transcript.py https://www.youtube.com/watch?v=ej2RqEWGUig ja
```

### channelId からの動画一覧

```
URL  : https://www.youtube.com/feeds/videos.xml?channel_id=<channelId>
WebFetch Prompt:
  "[チャンネル名]の直近10本の動画タイトルと公開日時、video_idを抽出。"
```

### 既知 channelId

| ハンドル | channelId |
|---------|-----------|
| @Kuroko_965 (くろこ) | `UCGDAdoVs7er9UOIF9KzP99Q` |
| 今日ポケch. (KYOUPOKE) | `UCmnZL4tFRl4sm-uJOxTLHmg` |
| @pokesol (ポケソル) | `UCeQNXy1ReMSa1GuK7nhMvIA` |

### 動画字幕の使い方

1. 動画タイトルにキーワード一致 (構築/パーティ/キャラランク/tier/環境/育成論) があれば字幕取得
2. サブエージェント (`general-purpose`) に要約依頼
3. 「数字根拠」ではなく「なぜ流行っているか」「廃人の評価」として活用

---

## 5. X (Nitter RSS) (Tier S 動向)

### 取得方法

```
URL  : https://nitter.net/<user>/rss
WebFetch Prompt:
  "@<user> の直近20件のポストを抽出。Pokemon Champions関連のみ優先、投稿日時付き。"
```

### Nitter インスタンス

| URL | 状態 (2026-04-30) |
|-----|------------------|
| nitter.net | 生存・推奨 |
| nitter.poast.org | 403 |
| nitter.privacydev.net | 不安定 |

死亡時は WebSearch `site:x.com @<user>` でフォールバック。

---

## 6. note 構築記事 (Tier A)

```
WebSearch Prompt:
  "site:note.com \"ポケモンチャンピオンズ 構築\" after:[YYYY-MM-DD]"
  例: site:note.com "ポケモンチャンピオンズ 構築" after:2026-04-25
```

直近 24-72h の構築記事を拾う。マスター到達者・廃人の構築事例として参照。

---

## データ集計テンプレート (構築提案前の確認)

各メンバーポケについて以下のテンプレを埋める:

```yaml
pokemon: ガブリアス
ranking: 1位
last_updated: 2026-04-28 23:44 JST
sources:
  - champs.pokedb: https://champs.pokedb.tokyo/pokemon/show/0445-00?rule=0
  - pokechamdb: https://pokechamdb.com/en/pokemon/garchomp?season=M-1&format=single

items:
  - { name: きあいのタスキ, rate: 40.5%, recommend: ✓ }
  - { name: こだわりスカーフ, rate: 30.6% }
  - { name: オボンのみ, rate: 13.2% }

abilities:
  - { name: さめはだ, rate: 99.1%, recommend: ✓ }

natures:
  - { name: ようき, rate: 69.9%, recommend: ✓ }
  - { name: いじっぱり, rate: 15.5% }

moves_top6:
  - { name: じしん, rate: 98% }
  - { name: げきりん, rate: 61% }
  - { name: ステルスロック, rate: 51.7% }
  - { name: がんせきふうじ, rate: 43% }
  - { name: どくづき, rate: 25% }
  - { name: スケイルショット, rate: 20.4% }

ev_top: H4 / A252 / S252 (55.3% 採用)

# 動画/X からの動向補強
recent_signals:
  - source: クロコ 4/26 動画
    note: ガブは S 級唯一、何でもできる
  - source: ポケソル 4/28 動画
    note: お盆ガブが激増、対策必要

# 私の構築の妥当性チェック
my_build:
  items: きあいのタスキ → ✓ (top1)
  ability: さめはだ → ✓ (top1)
  nature: ようき → ✓ (top1)
  moves: じしん/ドラゴンクロー/ほのおのキバ/つるぎのまい
    - じしん → ✓ (top1)
    - ドラゴンクロー → ✗ TOP6圏外、げきりん採用率61%なのでこちらを優先
    - ほのおのキバ → ✗ TOP6圏外、稀有採用
    - つるぎのまい → ✗ TOP6圏外、ステロ採用51%が標準
  conclusion: 技構成 3/4 がマイナー型。ステロ起点型へ修正必要。
```

このテンプレを 6 体分作って初めて構築完成。

---

## キャッシュ運用

DB 取得した型データは以下に保存:

```
~/.claude/skills/pokemon-champions/cache/usage_stats/YYYY-MM-DD/[pokemon].json
```

24h 以内のキャッシュは再取得不要。
