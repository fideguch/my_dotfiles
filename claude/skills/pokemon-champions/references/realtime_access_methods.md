# X / YouTube リアルタイム情報アクセスプロトコル

> WebFetch だと X (402) や YouTube 個別動画詳細が取れない問題への回避策集。
> ここで紹介する手法は全て**公開情報のみ**を扱い認証不要。
> 24h 鮮度のメタトレンドを掴むための SSOT。

---

## 1. YouTube — RSS フィード（認証不要 / WebFetch で OK）

### Step 1: チャンネル ID を取得

`@handle` 形式のチャンネルから内部 channelId (UCxxxxx 形式) を取り出す:

```bash
curl -s -L "https://www.youtube.com/@<HANDLE>" | grep -oE '"channelId":"[^"]+"' | head -1
# 例: @Kuroko_965 → "channelId":"UCGDAdoVs7er9UOIF9KzP99Q"
```

### Step 2: RSS フィードを叩く

```
https://www.youtube.com/feeds/videos.xml?channel_id=<UC形式ID>
```

WebFetch で取得可能。直近 15 件の動画タイトル / 公開日時 / 動画リンクが取れる。

### 既知 channelId 一覧（Pokemon Champions 関連）

| ハンドル | channelId | 信頼度 / 性格 |
|---------|-----------|--------------|
| @Kuroko_965 (くろこ) | `UCGDAdoVs7er9UOIF9KzP99Q` | Tier S（レート2500、7世代1位/8世代1位×9/9世代1位×4） |
| 今日ポケch. (KYOUPOKE) | `UCmnZL4tFRl4sm-uJOxTLHmg` | Tier S（X @KYOUPOKEch と同団体、最強プレイヤー集団） |
| @pokesol (ポケソル) | `UCeQNXy1ReMSa1GuK7nhMvIA` | Tier S（**キャラランク更新シリーズ**、4人で環境分析） |

### Step 3: 動画詳細（説明欄・概要）の取得

RSS にはタイトルしか無いので、内容は次のいずれかで補完:

- **WebFetch で動画 URL に直接当てる**（ヒット率: 中。description 取れる時は取れる）
- **`yt-dlp --write-info-json --skip-download <URL>`**（要 `pipx install yt-dlp` or `brew install yt-dlp`）
- **WebSearch で「動画タイトル」を再検索** → ブログ転載や引用が見つかれば内容取得可能

```bash
# yt-dlp 経由（インストール後）
pipx install yt-dlp  # 一度だけ
yt-dlp --write-info-json --skip-download --no-warnings <video_url> -o "/tmp/%(id)s.%(ext)s"
cat /tmp/<video_id>.info.json | jq '.description'
```

---

## 2. X (Twitter) — Nitter インスタンス（認証不要 / WebFetch で OK）

### 主要インスタンス（生存確認は流動的）

| URL | ステータス（2026-04-30 確認） | 形式 |
|-----|------------------------------|------|
| https://nitter.net/<user> | 生存（HTML） | プロフィール / ポスト一覧 |
| https://nitter.net/<user>/rss | 生存（RSS XML） | RSS フィード |
| https://nitter.poast.org/<user>/rss | 403 | （死亡時の予備） |
| https://nitter.privacydev.net/<user>/rss | 不安定 | （予備） |

### 利用例

```
WebFetch URL: https://nitter.net/KYOUPOKEch/rss
Prompt: "@KYOUPOKEch の最新ポストをタイトル/本文/投稿日時で抽出。Pokemon Champions関連のみ。"
```

### インスタンス生死確認

```bash
curl -sI "https://nitter.net/KYOUPOKEch/rss" | head -1
# HTTP/2 200 なら生存。403/404/502 なら別インスタンスへ。
```

### 既知 X アカウント（Pokemon Champions シングル系）

| ハンドル | プロフィール | 用途 |
|---------|------------|------|
| @KYOUPOKEch | KYOUPOKE / 配信者集団 | シングル上位の動向速報 |
| @Sifu_pokePress | ポケモンゲーム情報 | 公式情報・ランキング速報 |
| @poketettei | ポケモン徹底攻略 | データベース更新通知 |
| @nomaneko_world | のまねこ | 仕様変更解析 |

---

## 3. Nitter が全滅した場合のフォールバック

### 順に試す

1. **Google キャッシュ**: `https://www.google.com/search?q=site:x.com+@<user>+<keyword>`
2. **WebSearch 経由 X 結果**: クエリに `site:x.com` を含める
3. **Wayback Machine**: `https://web.archive.org/web/<timestamp>/https://twitter.com/<user>`
4. **vxtwitter プロキシ**: `https://api.vxtwitter.com/<user>/status/<id>`（個別ポストのみ）

### 商用 API（最終手段、設定要）

- snscrape (Python): `pip install snscrape; snscrape twitter-user <user> --max-results 50`
  → 2024 以降の X API 仕様変更で動作不安定
- Apify Twitter Scraper: 月額制、高精度
- twscrape (Python): セッション cookie 設定必要だが安定

---

## 4. 鮮度ベースの巡回プロトコル（T3 応答時）

毎回以下の順で叩く（並列推奨）:

```
[並列 1] champs.pokedb.tokyo の最新ランキング
[並列 2] pokechamdb.com/en?view=pokemon
[並列 3] yakkun.com/ch/ranking.htm
[並列 4] nitter.net/KYOUPOKEch/rss
[並列 5] youtube.com/feeds/videos.xml?channel_id=UCGDAdoVs7er9UOIF9KzP99Q (Kuroko)
[並列 6] note.com 検索: "ポケモンチャンピオンズ 構築 site:note.com 2026年4月"
```

各から最新 24-72h のシグナルを抽出し、合致した情報を構築提案に組み込む。

---

## 5. 実装メモ（lib/meta_fetcher.py への組み込み案）

将来的に `lib/meta_fetcher.py` を拡張:

```python
# 提案: lib/meta_fetcher.py
SOURCES = {
    "champs_db": "https://champs.pokedb.tokyo/pokemon/list?rule=0",
    "pokechamdb": "https://pokechamdb.com/en?view=pokemon",
    "yakkun_rank": "https://yakkun.com/ch/ranking.htm",
    "kyoupoke_rss": "https://nitter.net/KYOUPOKEch/rss",
    "kuroko_yt_rss": "https://www.youtube.com/feeds/videos.xml?channel_id=UCGDAdoVs7er9UOIF9KzP99Q",
}
TTL_HOURS = 24  # T3 応答での鮮度命層

def fetch_all_parallel():
    # asyncio + httpx で並列取得 + キャッシュ
    ...
```

---

## 6. 鮮度マーキング規則（HARD-GATE）

T3 応答冒頭に以下を必ず明記:

```
鮮度: < {hours}h
取得時刻: {ISO 8601}
一次ソース:
  - {URL 1} (last_updated: {timestamp})
  - {URL 2} (last_updated: {timestamp})
直近 24h トレンド検知:
  - {YouTube/X からの発見 1}
  - {YouTube/X からの発見 2}
```

24h 以内のトレンド検知が 0 件の場合は構築提案禁止。最低 1 件確保するまで再取得。
