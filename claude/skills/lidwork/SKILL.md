---
name: lidwork
description: MacBookの蓋を閉じてもスリープさせず、ローカルのClaude処理を継続させるモードのオン/オフ/状態確認。Triggers: "lidwork", "蓋を閉じて", "蓋閉じモード", "クラムシェル", "スリープ無効", "スリープさせないで", "閉じても動くように", "スリープに戻して", "lid close", "keep awake".
---

# lidwork — 蓋閉じ継続モード

MacBookの蓋を閉じてもスリープさせないモードを切り替える。
実体は `~/my_dotfiles/.my_commands/lidwork`（PATH配備済み）で、
`sudo pmset disablesleep 1|0` を安全ラッパー越しに呼ぶ。

## 背景（なぜ pmset disablesleep か）

- macOSは外部ディスプレイなしで蓋を閉じると **caffeinate では防げない**
  強制スリープ（Clamshell Sleep）に入る
- 唯一のネイティブな回避手段が `pmset disablesleep 1`（要root）
- この設定は**再起動後も維持される**。消し忘れは `.zshrc` の起動時警告
  「⚠️ lidwork ON」で可視化される

## 手順

### 状態確認（「今どうなってる？」）

```bash
lidwork          # ON/OFF を表示
```

裏付けは `pmset -g | grep SleepDisabled`（`1` = ON、行なし/0 = OFF）。

### ON / OFF

```bash
lidwork on       # 蓋を閉じてもスリープしない
lidwork off      # 通常のスリープ動作に戻す
```

1. まず上記コマンドを実行する
2. **成功**（✅表示）→ `pmset -g | grep SleepDisabled` で実状態を検証して報告
3. **`sudo: a password is required` で失敗**（exit 1）→ ClaudeのシェルにはTTYが
   ないため正常な挙動。ユーザーに次の2択を提示する:

   **A. 通常のターミナルタブで実行してもらう（すぐ済む）**
   ```bash
   lidwork on   # または lidwork off — パスワード入力あり
   ```

   **B. 一度だけNOPASSWD設定（以後Claudeから直接オンオフ可能）**

   下記をユーザー自身に通常のターミナルで実行してもらう。
   対象を `pmset disablesleep 1|0` の2コマンドに厳密に限定した設定であり、
   他のsudo操作には影響しない:
   ```bash
   echo "$USER ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0" \
     | sudo tee /etc/sudoers.d/lidwork >/dev/null \
     && sudo chmod 440 /etc/sudoers.d/lidwork \
     && sudo visudo -cf /etc/sudoers.d/lidwork
   ```
   設定後は `lidwork on|off` がClaudeからパスワードなしで通る。

## ON にしたら必ず伝える3点

1. **カバンに入れない**（蓋を閉じてもCPUは動作中。放熱できず危険）
2. **AC電源につないだままにする**（バッテリーでは消耗し続ける）
3. **終わったら `lidwork off`**（再起動しても勝手には戻らない）

## 検証方法

- ON後: `pmset -g | grep SleepDisabled` → `SleepDisabled 1`
- 蓋を閉じて動き続けたかの事後検証:
  `pmset -g log | grep "Entering Sleep"` に該当時間帯の
  `Clamshell Sleep` エントリが**ない**こと
- OFF後: 新しいシェルで ⚠️ 警告が消える

## 禁止事項

- Claudeが `/etc/sudoers.d/` を直接書かない（設定Bは必ずユーザー自身が実行）
- `disablesleep` を `pmset -a sleep 0` 等の別設定で代用しない
  （蓋閉じスリープは防げず、通常スリープだけ壊れる）
