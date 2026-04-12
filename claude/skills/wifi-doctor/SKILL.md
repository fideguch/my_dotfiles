---
name: wifi-doctor
description: "Wi-Fi環境診断スキル。近隣ネットワークスキャン・接続品質・速度テスト・チャンネル分析・干渉検出・ルーター設定ガイドを含む総合レポートを生成。"
---

# Wi-Fi Doctor

Wi-Fi 環境を総合診断し、チャンネル干渉・信号品質・速度を分析して、人間が読める評価文章と具体的な改善アクションを提示するスキル。

## When to Activate

- ユーザーがWi-Fiの速度・安定性・チャンネルについて言及したとき
- `/wifi-doctor` で明示的に呼び出されたとき
- キーワード: wifi遅い, ネット重い, Wi-Fi不安定, チャンネル変更, 回線遅い, Wi-Fi速度, ネットワーク診断

## Diagnostic Flow

以下の6ステップを順番に実行する。各ステップの実行結果を保持し、最後にレポートを生成する。

### Step 1: Swift スキャナー実行

CoreWLAN を使ってネットワーク環境をスキャンする。スキャナーは Swift インタープリタで実行（コンパイル不要、Location Services 権限が安定して取得できる）。

```bash
swift ~/.claude/skills/wifi-doctor/scripts/wifi-scan.swift
```

絶対パスで実行する。シンボリックリンク経由で `~/my_dotfiles/claude/skills/wifi-doctor/scripts/wifi-scan.swift` が実行される。出力はJSON。

**JSON構造:**
- `current`: 現在の接続情報（ssid, rssi, noise, snr, channel, phyMode, txRate, security, ipAddress）— 未接続時は `null`
- `ssidInferred`: SSIDがスキャン結果からの推定値の場合 `true`（推定SSIDは最強APと一致しない可能性あり）
- `networks`: 近隣ネットワーク一覧（ssid, bssid, rssi, noise, channel）
- `interfaceInfo`: インターフェース情報（hardwareAddress, supportedPHYModes, countryCode）
- `error`: エラーメッセージ（正常時はnull）

**エラー時の対処:**
- `error` に "Location Services" を含む場合: ユーザーに「システム設定 > プライバシーとセキュリティ > 位置情報サービス」からターミナルアプリへの許可を案内
- JSON出力なしの場合: `system_profiler SPAirPortDataType` をフォールバックとして使用

### Step 2: 追加接続情報取得

並行して以下を実行:

```bash
# ゲートウェイIP
netstat -rn | grep default | awk '{print $2}' | head -1

# DNS サーバー
scutil --dns | grep nameserver | head -3

# 外部接続確認
curl -s -o /dev/null -w '%{time_total}' https://www.google.com --max-time 5
```

### Step 3: スピードテスト（オプション）

```bash
# Ookla Speedtest CLI が利用可能か確認
which speedtest 2>/dev/null
```

- **インストール済み**: `speedtest --format=json --accept-license` を実行（初回実行時にGDPR同意が必要な場合、ユーザーに案内する）
- **未インストール**: スピードテストをスキップし、以下を表示:
  ```
  スピードテスト: 未実施（speedtest CLI 未インストール）
  インストール方法: brew install speedtest
  ```
  **自動インストールはしない。** ユーザーの明示的な同意なしにパッケージをインストールしない。

**speedtest JSON から抽出する値:**
- `download.bandwidth` → Mbps (÷ 125000)
- `upload.bandwidth` → Mbps (÷ 125000)
- `ping.latency` → ms
- `ping.jitter` → ms
- `server.name`, `server.location`

### Step 4: 環境リスク分析

Step 1-3 の収集データを元に、以下のリスク項目を評価する。
**速度テスト結果に依存しない項目を中心に据える**（Wi-Fiが遅いときにスキルを実行できない場合でも有用）。

| リスク項目 | 判定基準 | 重み | 検出方法 |
|-----------|---------|------|---------|
| チャンネル混雑 | 同チャンネルにAP 2台以上 | **高** | networks のチャンネル集計 |
| 隣接チャンネル干渉 | ±2ch 以内に RSSI > -70 の AP | **高** | 2.4GHz の networks をチャンネル距離で分析 |
| 信号品質 (SNR) | SNR < 20dB | **高** | current.snr |
| 信号強度 | RSSI < -70dBm | **中** | current.rssi |
| バンド非効率 | 5GHz 対応なのに 2.4GHz 接続 | **中** | current.channel.band + interfaceInfo.supportedPHYModes |
| PHYモード制限 | 802.11n 以下で接続 | **低** | current.phyMode |
| チャンネル幅制限 | 20MHz に制限 | **低** | current.channel.width |
| ノイズフロア | noise > -85dBm | **低** | current.noise |

**総合評価ランク（5段階）:**

**上から順に評価し、最初に該当したランクを採用する:**

| 優先 | ランク | 条件 | 表示 |
|------|--------|------|------|
| 1 | 深刻 | SNR < 10 または RSSI < -80 | 早急な対処が必要です |
| 2 | 要改善 | 高リスク 2件以上 | 改善が推奨されます |
| 3 | やや不安定 | 高リスク 1件、または 中リスク 2件以上 | 時折遅延が発生する可能性があります |
| 4 | 良好 | 高リスク 0件、中リスク 1件以下 | おおむね良好です |
| 5 | 快適 | 高リスク 0件、中リスク 0件、SNR ≥ 25 | 快適に利用できます |

### Step 5: チャンネル推奨算出

**2.4GHz チャンネルスコアリング（ch 1, 6, 11 のみ評価）:**

各チャンネルについて:
```
score = -(同チャンネルAP数 × 10) + min(同チャンネルAPの最大RSSI, -100) - |noise_floor|
```
- AP数が少ないほど高スコア（AP 0台なら0ペナルティ）
- 競合APの信号が弱いほど高スコア（RSSI -90 → -90加算 vs RSSI -60 → -60加算。弱い方がペナルティ小）
- ノイズフロアが低いほど高スコア
- APが0台のチャンネルは `min(RSSI)` を `-100` とする

隣接チャンネル干渉ペナルティ:
- ch 1 の AP は ch 2, 3 にも-5ずつ影響
- ch 6 の AP は ch 4, 5, 7, 8 にも-5ずつ影響
- ch 11 の AP は ch 9, 10 にも-5ずつ影響

**5GHz チャンネルスコアリング:**
同様の式で、検出された5GHzチャンネル全てを評価。DFS チャンネル（52-144）はレーダー退避リスクがあるため -5 のペナルティ。

**推奨出力:**
- 最も高スコアのチャンネルを推奨
- 現在のチャンネルとの差分を説明
- 5GHz が利用可能なら帯域切り替えも推奨

### Step 6: レポート生成

以下のフォーマットで診断レポートを出力する。**評価文章を先頭に配置**し、数値は後ろにまとめる。

---

#### レポートテンプレート

```markdown
# Wi-Fi 診断レポート
**診断日時:** {YYYY-MM-DD HH:MM}  |  **インターフェース:** en0

---

## 総合評価

{ランクに応じた評価文章。2-3段落で以下を含む:}
- 現在の接続状況の要約（SSID、帯域、チャンネル）
- 環境リスクの主要な問題点（あれば）
- スピードテスト結果の実用的な評価（実施した場合）

**今すぐできること:**
1. {最も効果的な改善アクション}
2. {次に効果的な改善アクション}
3. {あれば追加アクション}

---

## 環境リスク分析

| リスク項目 | 状態 | 重み | 詳細 |
|-----------|------|------|------|
| チャンネル混雑 | {OK/注意/警告} | 高 | {検出結果} |
| 隣接チャンネル干渉 | ... | 高 | ... |
| ... | ... | ... | ... |

---

## チャンネル推奨

{推奨チャンネルと理由を文章で説明}

### 2.4GHz チャンネル別スコア

| チャンネル | AP数 | 最大RSSI | スコア | 推奨 |
|-----------|------|---------|--------|------|
| 1 | ... | ... | ... | ... |
| 6 | ... | ... | ... | ... |
| 11 | ... | ... | ... | ... |

### 5GHz チャンネル別スコア（検出されたもの）

| チャンネル | AP数 | 最大RSSI | スコア | 推奨 |
|-----------|------|---------|--------|------|

---

## 現在の接続情報

| 項目 | 値 | 評価 |
|------|-----|------|
| SSID | {ssid} | — |
| Signal (RSSI) | {rssi} dBm | {-50以上: Excellent / -60以上: Good / -70以上: Fair / それ以下: Poor} |
| Noise | {noise} dBm | — |
| SNR | {snr} dB | {30以上: Excellent / 20以上: Good / それ以下: Poor} |
| Channel | {ch} ({band}, {width}) | — |
| PHY Mode | {phyMode} | — |
| Tx Rate | {txRate} Mbps | — |
| Security | {security} | — |
| IP Address | {ip} | — |
| Gateway | {gateway} | — |

---

## 近隣ネットワーク一覧

| # | SSID | Channel | Band | Width | RSSI | Noise |
|---|------|---------|------|-------|------|-------|
{ネットワーク一覧、RSSI順}

---

## スピードテスト結果

{実施した場合:}

| 項目 | 結果 | 実用評価 |
|------|------|---------|
| Download | {dl} Mbps | {実用評価テキスト} |
| Upload | {ul} Mbps | {実用評価テキスト} |
| Ping | {ping} ms | {実用評価テキスト} |
| Jitter | {jitter} ms | — |
| Server | {server} | — |

**実用評価の基準:**
- Download: 100+ Mbps → 4K動画・大容量DL快適 / 25-100 → HD動画OK / 10-25 → Web閲覧OK / <10 → 遅い
- Upload: 20+ → ビデオ会議快適 / 5-20 → 通常利用OK / <5 → アップロード遅延あり
- Ping: <20ms → ゲーム/通話最適 / 20-50 → 通常利用OK / 50-100 → やや遅延 / >100 → 要改善

{未実施の場合:}
スピードテスト未実施（speedtest CLI 未インストール）
インストール: `brew install speedtest`

---

## 前回比較

{~/.cache/wifi-doctor/history.json に前回データがある場合のみ表示}

### 場所推定ロジック

前回と同じ場所かどうかを以下のフィンガープリントで推定する:

1. **SSID 一致**: 同じルーター名 → 同じ場所の可能性が高い
2. **ゲートウェイ IP 一致**: 同じゲートウェイ → 同一ネットワーク
3. **近隣AP構成の類似度**: 検出されたSSID群のうち50%以上が前回と一致 → 同じ場所

**判定:**
- SSID + ゲートウェイの両方一致 → **同一場所（確信度: 高）** → 前回比較を表示
- SSIDのみ一致（チェーン店Wi-Fi等の可能性） → 近隣AP構成で補完判定
- 両方不一致 → **別の場所** → 「別の場所からの診断のため、前回比較はスキップします」と表示

**同一場所の場合の比較テーブル:**

| 項目 | 前回 ({前回日時}) | 今回 | 変化 |
|------|------|------|------|
| RSSI | ... | ... | {改善/悪化/変化なし + dB差} |
| SNR | ... | ... | ... |
| Channel | ... | ... | {変更あり/なし} |
| Download | ... | ... | {Mbps差} |
| 評価ランク | ... | ... | {ランク変化} |
| 場所 | {location_label} | {location_label} | 同一場所 |

**別の場所の場合:**
> 前回（{前回日時}）は「{前回のSSID}」（{前回のlocation_label}）で診断しました。
> 今回は別の場所のため、前回比較はスキップします。

---

## Buffalo ルーター チャンネル変更手順

{references/buffalo-guide.md の内容を読み込んで表示}
```

---

### 履歴保存

レポート生成後、以下のJSONを `~/.cache/wifi-doctor/history.json` に追記:

```bash
mkdir -p ~/.cache/wifi-doctor && chmod 700 ~/.cache/wifi-doctor
```

**ファイル形式:** JSON配列。各エントリがオブジェクト。

```bash
# 読み込み（前回データ取得）
cat ~/.cache/wifi-doctor/history.json 2>/dev/null || echo '[]'

# 書き込み（追記 + 30件制限）— Claudeが以下のロジックで更新:
# 1. 既存配列を読み込む（なければ空配列）
# 2. 新しいエントリを末尾に追加
# 3. 30件を超えたら先頭から削除
# 4. JSON配列全体を上書き保存
```

```json
{
  "timestamp": "2026-04-13T15:30:00+09:00",
  "location": {
    "ssid": "Buffalo-G-7FD1",
    "gateway": "192.168.11.1",
    "nearby_ssids": ["auhome_acy6Um", "ssw-pc-3cf605"],
    "label": "自宅 (Buffalo-G-7FD1)"
  },
  "rssi": -60,
  "noise": -94,
  "snr": 34,
  "channel": 11,
  "band": "2.4GHz",
  "phyMode": "802.11n",
  "download_mbps": 45.2,
  "upload_mbps": 12.8,
  "ping_ms": 15.3,
  "rank": "やや不安定",
  "recommended_channel": 1
}
```

**location フィールド:**
- `ssid`: 接続中のSSID
- `gateway`: ゲートウェイIP（Step 2で取得）
- `nearby_ssids`: 検出された近隣SSIDリスト（hidden除く、上位5件）— 場所類似度判定に使用
- `label`: 場所の表示ラベル。初回は「自宅 ({SSID})」等をClaude が推定する:
  - Buffalo/NEC/ELECOM等のホームルーター → 「自宅」
  - 企業名やオフィス系SSID → 「オフィス」
  - カフェ・ホテル・公共系SSID → 「外出先」
  - 不明 → SSID名をそのまま使用

- 最大30件保持（古いものから削除）
- 速度テスト未実施時は download/upload/ping を null にする

## Notes

- Swift スキャナーはインタープリタモード（`swift` コマンド）で実行する。コンパイル済みバイナリは Location Services の権限が別途必要なため不安定
- スキャン結果の精度は Location Services の許可状況に依存する。許可されていない場合、SSID が hidden になる
- 5GHz DFS チャンネル（52-144）は、現在そのチャンネルに接続していない限りスキャンで検出できない場合がある
- Buffalo ルーター以外のルーターの場合は、管理画面URLとナビゲーションが異なるため一般的な案内に切り替える
