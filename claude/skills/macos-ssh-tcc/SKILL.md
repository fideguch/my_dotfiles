---
name: macos-ssh-tcc
description: SSH 越しや Bash で ~/Desktop・~/Documents・~/Downloads が "Operation not permitted" になるとき（macOS TCC・フルディスクアクセス）。ssh-tcc-doctor で診断し、sshd-session への FDA 付与手順を示す
---

# macOS SSH — TCC による "Operation not permitted"

> 横断ルール。iPhone の Termius 等から Mac に SSH したとき、
> `~/Desktop` 配下で `ls: .: Operation not permitted` になる問題の
> 診断・修正手順を定義する。診断コマンドは `ssh-tcc-doctor`。

## 症状 (Symptom)

SSH ログイン自体は成功してシェルも起動するのに、特定ディレクトリだけ操作できない。

```
$ cd ~/Desktop/start
$ ls
ls: .: Operation not permitted
```

- `~/Desktop` `~/Documents` `~/Downloads` とその**サブディレクトリ全て**で発生する
- ローカル端末（iTerm2 / cmux 等）からは同じディレクトリが正常に読める
- パーミッション（`drwxr-xr-x`）や ACL には異常がない
- `sudo` を付けても解決しない（TCC は uid ではなくコード署名で判定するため）

## 根本原因 (Root Cause — 検証済み)

macOS の TCC（Transparency, Consent and Control）は
Desktop / Documents / Downloads / iCloud Drive を保護しており、
フルディスクアクセス(FDA)を持たないプロセスからの読み取りを拒否する。

**OpenSSH 9.8 以降、sshd はプロセスが分割された。**
実際にログインシェルを起動するのは `/usr/libexec/sshd-session` という
別バイナリで、コード署名 ID も別物になっている:

```
launchd
  └─ /usr/libexec/sshd-keygen-wrapper   identifier "com.apple.sshd-keygen-wrapper"
       └─ /usr/sbin/sshd -i             identifier "com.apple.sshd"
            └─ /usr/libexec/sshd-session identifier "com.apple.sshd-session"  ← ここがシェルの親
                 └─ zsh（ユーザーのシェル）
```

TCC の許可は**署名 ID 単位**で管理されるため、
従来 FDA を付与していた `com.apple.sshd-keygen-wrapper` の許可は
`com.apple.sshd-session` に引き継がれない。結果、SSH 越しのときだけ拒否される。

macOS 26 系は OpenSSH 10.x を同梱しているためこの分割モデルに該当する
（`ssh -V` で確認できる）。

### 誤診しやすい原因（いずれも無関係）

| 疑われがちな原因 | 判定方法 |
|---|---|
| Tailscale の設定 | `tailscale debug prefs \| grep RunSSH` が `false` なら Tailscale は経路のみ。SSH サーバーは macOS 標準 sshd であり Tailscale は無関係 |
| SSH クライアント（Termius 等）の設定 | クライアント側では TCC に一切関与できない。サーバー側の問題 |
| ファイルパーミッション / ACL | `ls -lde` で確認。TCC 起因なら POSIX 権限は正常 |
| iCloud の「デスクトップと書類」同期 | `cd ~/Desktop && pwd -P` が `~/Library/Mobile Documents/...` を返すかで判別 |

## 診断 (Diagnosis)

```bash
ssh-tcc-doctor          # 診断のみ
ssh-tcc-doctor --fix    # 診断 + システム設定の FDA ペインを開く
```

SSH 先でも同じコマンドを実行すると、実アクセス検証が実環境の結果になる。

手動で確認する場合:

```bash
# FDA の付与状況（TCC.db 読み取り自体に FDA が必要）
sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select client, auth_value from access
    where service='kTCCServiceSystemPolicyAllFiles' and client like '%ssh%';"
# auth_value: 0=拒否 / 2=許可 / 3=制限付き

# 各バイナリの署名 ID
codesign -d -r- /usr/libexec/sshd-session
```

## 対処 (Fix)

### 推奨: `sshd-session` に FDA を付与

1. システム設定 → プライバシーとセキュリティ → **フルディスクアクセス**
2. `+` → ファイル選択ダイアログで **Command+Shift+G**
3. `/usr/libexec/sshd-session` を入力して追加し、トグルを ON
4. 念のため `/usr/sbin/sshd` も同様に追加する
5. SSH クライアントから**再接続**（`sshd-session` プロセスが作り直される）
6. 直らなければ システム設定 → 一般 → 共有 → **リモートログインを OFF → ON**

> `sudo` や `tccutil` でこの許可を追加することはできない。
> SIP 有効時 TCC.db は root でも書き込み不可で、`tccutil` は reset 専用。
> **GUI 操作でしか付与できない。**

### 代替: 作業ディレクトリを保護領域外へ移す

TCC が保護するのは Desktop / Documents / Downloads / iCloud Drive など。
`~/dev/` のような保護対象外へ移せば FDA 不要で恒久的に安定する。
モバイルから常用するリポジトリはこちらを推奨。

### 再発時

macOS のアップデートで `/usr/libexec/` 配下のバイナリが置き換わると
FDA 設定が無効化されることがある。
再発したら FDA リストから**削除 → 再追加**する。

## Claude への指示 (For Claude)

- ユーザーが SSH 越しの `Operation not permitted` を報告したら、
  まず Tailscale や SSH クライアントを疑わず、`ssh-tcc-doctor` を実行する
- FDA の付与は GUI 必須。「修正して」と言われても TCC.db を直接書こうとしない
  （SIP により失敗する）。診断結果と手順を提示し、`--fix` で設定画面を開く
- `sudo` での回避を提案しない。TCC は uid ではなくコード署名で判定する

> **Language note**: This rule applies universally across all languages and project types.
