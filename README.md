# my_dotfiles

macOS (Apple Silicon) 用の個人dotfiles。zsh, Vim, Starship を中心としたターミナル環境。

## クイックインストール

```bash
git clone https://github.com/fideguch/my_dotfiles.git ~/my_dotfiles
cd ~/my_dotfiles
chmod +x set_up.sh
./set_up.sh
```

セットアップスクリプトが以下を自動で行います:

1. Homebrew のインストール (未導入の場合)
2. Brewfile に記載されたパッケージのインストール
3. 各設定ファイルのシンボリックリンク作成
4. vim-plug のインストール (未導入の場合)

## セットアップ後の手動ステップ

```bash
# Vimプラグインをインストール
vim +PlugInstall +qall

# Starship を最新に更新
brew upgrade starship

# fzf のキーバインドを有効化 (初回のみ)
$(brew --prefix)/opt/fzf/install --key-bindings --completion --no-update-rc
```

## 含まれるファイル

| ファイル | 説明 |
|---|---|
| `.zshrc` | Zsh設定 — ヒストリ、補完、エイリアス、PATH管理 |
| `.vimrc` | Vim設定 — プラグイン、キーマップ、エディタ設定 |
| `starship.toml` | Starshipプロンプト設定 |
| `Brewfile` | Homebrewパッケージ一覧 |
| `.my_commands/` | 自作シェルスクリプト |
| `.vim/` | Vimカラースキーム、vim-plug |
| `set_up.sh` | セットアップスクリプト |

## 主なVimキーマップ

| キー | 動作 |
|---|---|
| `Ctrl+e` | NERDTree (ファイルツリー) の開閉 |
| `Ctrl+n` | ファイル検索 (fzf) |
| `Ctrl+p` | バッファ一覧 (fzf) |
| `Ctrl+z` | 最近開いたファイル (fzf) |
| `Ctrl+g` | ファイル内容をgrep検索 (ripgrep) |
| `Tab+l/h` | タブ移動 |

## 主なzshエイリアス

| エイリアス | コマンド |
|---|---|
| `v`, `vi` | vim |
| `vz` | vim ~/my_dotfiles/.zshrc |
| `vv` | vim ~/my_dotfiles/.vimrc |
| `g` | git |
| `d` | docker |
| `dc` | docker-compose |
| `cc` | claude (Claude Code) |
| `mkcd <dir>` | mkdir + cd を同時実行 |

## ポケモン背景 (iTerm2)

[Pokemon-Terminal](https://github.com/LazoCoder/Pokemon-Terminal) を使ってiTerm2の背景にポケモンを表示。

| 状態 | ポケモン | 背景色 |
|---|---|---|
| 通常 | ゲンガー | ダークパープル |
| Claude Code起動中 | ミュウツー | 薄紫 |

`cc` 等のClaude Codeエイリアスで自動切替。手動で変更する場合:

```bash
pokemon -n gengar     # ゲンガーに変更
pokemon -n umbreon    # ブラッキーに変更
pokemon -t ghost      # ゴーストタイプからランダム
pokemon               # 全768匹からランダム
```

## 更新

```bash
cd ~/my_dotfiles
git pull
brew bundle install --file=Brewfile
vim +PlugUpdate +qall
```

## 必要環境

- macOS (Apple Silicon)
- [Nerd Font](https://www.nerdfonts.com) がターミナルに設定済みであること (アイコン表示用)
