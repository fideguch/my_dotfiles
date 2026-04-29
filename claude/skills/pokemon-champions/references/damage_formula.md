# ダメージ計算式 — SSOT

> **このスキルは独自のダメ計実装を持たない**。
> 全ての計算は `@smogon/calc@^0.11.0` に委譲し、`bin/pokechamp-calc` がその薄いラッパとして動作する。

## SSOT 宣言

- ライブラリ: [@smogon/calc](https://www.npmjs.com/package/@smogon/calc) version 0.11.0
- 実装ソース: [smogon/damage-calc on GitHub](https://github.com/smogon/damage-calc)
- ライセンス: MIT
- データ整合性: Showdown commit `808f8584298878b2eb5d8dd3638d660877b5d4cf` (2026-04-26 cut) の data/* と同期

このバージョンは Showdown のサーバ側計算と同じロジックを共有しているため、実機 (Pokemon Showdown!) と完全一致する。

## 計算式の概要 (一般式 / 詳細は @smogon/calc 委譲)

```
damage = floor(
  ((((2 * level / 5 + 2) * power * A / D) / 50) + 2)
  * stab        // 1.0 / 1.5 / 2.0 (テラ STAB は 2.0)
  * type        // 0.25 / 0.5 / 1.0 / 2.0 / 4.0
  * critical    // 1.5 (gen 6+)
  * random      // 0.85-1.00 (16段階ロール)
  * burn        // 0.5 (物理 + 鈍ら以外)
  * weather     // 0.5 / 1.0 / 1.5
  * other       // フィールド / 持ち物 / 特性 etc.
)
```

各係数の詳細分岐は `@smogon/calc` の `calc.ts` 参照。本スキルでは式の独自実装はしない。

## ロール（乱数16段階）

ダメージは整数の最大値に対して 0.85～1.00 を乗じた **16段階の整数列** が返る。
@smogon/calc は `result.damage` を `number[16]` として返す（multi-hit はネスト配列）。

| 配列 index | 倍率 | 確率 |
|---|---|---|
| 0 | 0.85 | 1/16 |
| 1 | 0.86 | 1/16 |
| ... | ... | 1/16 |
| 15 | 1.00 | 1/16 |

「乱数1/16」とは index 0 のみで条件達成（最低ロール限定）の意味。

## 主要分岐 (覚書、計算は委譲)

| 分岐 | 値 |
|---|---|
| 物理/特殊 | move.category で分岐 |
| 急所 | 1.5x（gen 6+）、ガード持ちは無効 |
| 天候 | 晴れ Fire 1.5x、雨 Water 1.5x、晴れ Water 0.5x、雨 Fire 0.5x |
| フィールド | 各 1.3x（自タイプ技 to grounded） |
| やけど | 物理 0.5x（特性"鈍感"等で無効化） |
| STAB | 通常 1.5x、適応力 2.0x、テラ + STAB は 2.0x |
| テラ | 元タイプの STAB 維持、テラタイプの STAB は 2.0x |
| メガ進化 | アイテム`*ite` で自動切替（calc が処理） |
| ダイマ | maxHP 2x（HP 表示）、技は max-power 上書き |
| Z技 | base power 上書き、`useZ:true` で適用 |

## 入出力スキーマ (bin/pokechamp-calc)

詳細: `scripts/calc_wrapper.ts` 冒頭コメント。

### 入力 (stdin JSON)

```json
{
  "gen": 9,
  "format": "Singles",
  "attacker": {
    "name": "Garchomp",
    "level": 100,
    "item": "Choice Band",
    "ability": "Rough Skin",
    "nature": "Jolly",
    "evs": { "atk": 252, "spe": 252 },
    "ivs": { "hp": 31 },
    "boosts": { "atk": 0 },
    "status": "",
    "teraType": "Ground"
  },
  "defender": { "...": "..." },
  "move": {
    "name": "Earthquake",
    "isCrit": false,
    "useZ": false,
    "useMax": false,
    "hits": 1
  },
  "field": {
    "weather": "Sun",
    "terrain": "Electric",
    "isGravity": false,
    "attackerSide": { "isReflect": false },
    "defenderSide": { "isSR": true, "spikes": 0 }
  }
}
```

### 出力 (stdout JSON)

```json
{
  "ok": true,
  "damage": [295, 298, 301, 306, 309, 312, 316, 319, 322, 327, 330, 333, 337, 340, 343, 348],
  "min": 295,
  "max": 348,
  "percent_min": 117.1,
  "percent_max": 138.1,
  "defender_max_hp": 252,
  "ko_chance": { "chance": 1, "n": 1, "text": "guaranteed OHKO" },
  "desc": "252 Atk Choice Band Garchomp Earthquake vs. 4 HP / 0 Def Mimikyu: 295-348 (117 - 138%) -- guaranteed OHKO",
  "attacker_stats": { "hp": 357, "atk": 359, "...": "..." },
  "defender_stats": { "...": "..." },
  "elapsed_ms": 5.73
}
```

## 検証された fixtures

`tests/calc_fixtures.json` に以下を保存（10/10 PASS）:

1. 鉢巻ガブEQ vs ミミッキュ（OHKO）
2. 珠ガブEQ vs HBドオー（OHKO）
3. テラ Ground ガブ EQ STAB上昇
4. シングル前提（スプレッド0.75x なし）
5. メガクチート Play Rough vs Toxapex
6. Z技 ハイドロベスター
7. ダイマ ダイストリーム
8. やけど物理半減
9. 晴れオーバーヒート 1.5x
10. クリティカル + ステロ込み

## なぜ独自実装しないか

1. **精度リスク**: ダメ計の分岐は世代ごとに数百あり、自前実装は永続バグの温床
2. **メンテコスト**: 新世代追加の度に追従工数発生
3. **ライセンス**: `@smogon/calc` は MIT、再配布制限なし
4. **検証コスト**: 公式計算機との差分テストを毎回作るのは非現実的

## Sources

- @smogon/calc: https://www.npmjs.com/package/@smogon/calc
- damage-calc repo: https://github.com/smogon/damage-calc
- Bulbapedia damage formula: https://bulbapedia.bulbagarden.net/wiki/Damage
- Smogon mechanics docs: https://www.smogon.com/dp/articles/damage_formula
