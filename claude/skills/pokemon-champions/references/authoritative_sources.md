# Pokemon Champions — Authoritative Source Whitelist (HARD-GATE v3)

> **CRITICAL RULE**: 構築・メタ・型・採用率の T3 / MIXED 応答は、
> このリストを **必ず最初に確認** すること。
> メタは 24h 単位で回るので、ここに無いソースは「補助参考」扱い。

> **Tier 階層 v3 (2026-04-30 改訂)**:
> ユーザー指摘で「動画偏重 → 公式サイト優先」に再構築。
> **数字 (採用率/型/使用率) は DB 系 (Tier S+) 必須**。動画は感覚値・補完。

---

## Tier S+ — 構築の数字根拠 (最優先・必須)

ポケ単位の **持ち物・技・性格・努力値の採用率%** を取れる唯一のソース層。
構築提案の前に**必ずここから**型データを取得すること。

| URL | 種別 | 取得可能データ |
|-----|------|---------------|
| `https://champs.pokedb.tokyo/pokemon/show/[ZZZZ-NN]?rule=0` | DB(JP) | 持ち物/技/性格/努力値%、最頻パターン、共起ポケ |
| `https://pokechamdb.com/en/pokemon/[name]?season=M-1&format=single` | DB(EN/JP) | 同上、英名でクエリ |
| `https://yakkun.com/ch/` (※公式扱い) | DB(JP) | 実装/未実装、育成論、種族値、技、特性 |

詳細な使い方は [data_extraction_guide.md](./data_extraction_guide.md) 参照。

### URL の組み立て方

#### champs.pokedb.tokyo

```
https://champs.pokedb.tokyo/pokemon/list?rule=0          ← TOP30 全体ランキング
https://champs.pokedb.tokyo/pokemon/show/0445-00?rule=0  ← ガブリアス個別
https://champs.pokedb.tokyo/pokemon/show/0445-50?rule=0  ← メガガブリアス（フォーム番号 50）
https://champs.pokedb.tokyo/pokemon/show/0149-00?rule=0  ← カイリュー個別
https://champs.pokedb.tokyo/pokemon/show/[図鑑番号4桁]-[フォーム番号2桁]?rule=0
```

| パラメータ | 説明 |
|-----------|------|
| 図鑑番号 4 桁 | 0001-1025、ゼロ埋め必須 |
| フォーム番号 2 桁 | 通常=00、メガ=50、リージョン違い=10/20/30、その他特殊 |
| rule | 0=シングル、1=ダブル |

#### pokechamdb.com

```
https://pokechamdb.com/en?view=pokemon                   ← TOP30 全体
https://pokechamdb.com/en/pokemon/garchomp?season=M-1&format=single
https://pokechamdb.com/en/pokemon/[英名小文字]?season=M-1&format=single
```

英名は Showdown 標準（hyphen-case）。例:
- ガブリアス → `garchomp`
- アーマーガア → `corviknight`
- カバルドン → `hippowdon`
- メガゲンガー → `gengar`（DB側ではメガはフォーム別ページじゃなく持ち物統計で判断）

#### yakkun.com/ch/

```
https://yakkun.com/ch/                                    ← TOP
https://yakkun.com/ch/zukan/n445                          ← ガブリアス図鑑
https://yakkun.com/ch/theory/p445                         ← ガブリアス育成論
https://yakkun.com/ch/ranking.htm                         ← 使用率
https://yakkun.com/ch/changes.htm                         ← SVからの変更点
https://yakkun.com/ch/items.htm                           ← 持ち物一覧
```

注: yakkun は WebFetch 経由で 403 になることがある。代替で WebSearch + `site:yakkun.com/ch/` を使う。

---

## Tier S — 24h 鮮度のメタ動向 (感覚・評価)

数字が取れた後の **「なぜそれが強いのか」「最近何が流行っているか」** の補完層。
構築の根拠としては Tier S+ より弱いが、**新興構築・廃人感覚の最先端** を捕まえる。

### 配信者 YouTube（RSS で全文取得可）

| ハンドル | channelId | 性格 |
|---------|-----------|------|
| くろこ (Kuroko_965) | `UCGDAdoVs7er9UOIF9KzP99Q` | レート2500、7世代1位/8世代1位×9/9世代1位×4 |
| 今日ポケch. (KYOUPOKE) | `UCmnZL4tFRl4sm-uJOxTLHmg` | KYOUPOKE 団体 YouTube側、構築論・初心者コーチング |
| ポケソル (pokesol) | `UCeQNXy1ReMSa1GuK7nhMvIA` | キャラランク更新シリーズ、4人で環境分析 |

### X (Nitter RSS で取得可)

| ハンドル | URL |
|---------|-----|
| @KYOUPOKEch | https://nitter.net/KYOUPOKEch/rss |
| @poketettei | https://nitter.net/poketettei/rss |
| @Sifu_pokePress | https://nitter.net/Sifu_pokePress/rss |

詳細アクセス方法: [realtime_access_methods.md](./realtime_access_methods.md)

---

## Tier A — 補助参考 (週次・補完)

| URL | 用途 |
|-----|------|
| `https://yakkun.com/bbs/party/list/?soft=4&rule=0&sort=rank` | yakkun BBS 構築投稿 |
| WebSearch: `site:note.com "ポケモンチャンピオンズ 構築" after:[YESTERDAY]` | note 新着 |
| `https://www.smogon.com/forums/threads/pokemon-champions-bss-viability-rankings.3780943/` | 海外 Smogon BSS Viability |

---

## Tier B — 二次まとめ (裏取り、結論を変えない)

| URL | 用途 |
|-----|------|
| `https://game8.jp/pokemon-champions/` | 個別育成論まとめ |
| `https://altema.jp/pokemonchampions/` | TIER 表 |
| `https://gamewith.jp/pokemon-champions/` | 個別解説 |
| `https://gamerch.com/pokemonchampions/` | TOP100 |

---

## Tier C — オンデマンド (特殊用途)

- Reddit r/PokemonChampionsCompetitive
- PokeaimMD ガイド
- showdowntier.com

---

## 構築提案プロトコル（HARD-GATE）

T3 / MIXED で構築・型・持ち物を語る前に:

1. **Tier S+ から数字取得** (champs.pokedb と pokechamdb 両方)
2. **yakkun で実装確認** ([implementation_status.md](./implementation_status.md))
3. **Tier S 動画で「なぜ」の補完** (24h-72h鮮度)
4. **Tier A の note 構築記事で類似先行事例確認**
5. 採用率 30% 未満の選択は **「マイナー型」と明示**して提案
6. ナーフ反映済みかどうか **[implementation_status.md](./implementation_status.md)** で確認

詳細チェックリスト: [build_proposal_protocol.md](./build_proposal_protocol.md)

---

## 鮮度マーキング規則

T3 応答冒頭に必ず明記:

```
鮮度: < {hours}h
取得時刻: {ISO 8601}
一次ソース (Tier S+):
  - champs.pokedb (last_updated: {timestamp})
  - pokechamdb (last_updated: {timestamp})
動向ソース (Tier S):
  - YouTube ${チャンネル} ${タイトル} ({date})
  - X @${user} ポスト ({date})
```

24h 以内のトレンドが 0 件なら構築提案禁止。

---

## 信頼度スコア

| Tier | 信頼度 | 鮮度 | 役割 |
|------|-------|------|------|
| S+ | 0.95 | 24-72h | 数字根拠 (型/採用率) |
| S | 0.85 | < 24h | 動向・感覚 (廃人評価) |
| A | 0.7 | 1-7d | 構築事例 |
| B | 0.5 | 任意 | 裏取り |
| C | 0.3 | 任意 | 特殊用途のみ |

複数ソースで合致 → +0.05 / 件
矛盾 → 新しい方を採用、Tier S+ > S > A の順で重み付け
