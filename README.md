# my_dotfiles

macOS (Apple Silicon) 用の個人dotfiles。zsh, Vim, Starship を中心としたターミナル環境。

## セットアップ

```bash
git clone https://github.com/fideguch/my_dotfiles.git ~/my_dotfiles
cd ~/my_dotfiles
chmod +x set_up.sh
./set_up.sh
```

スクリプトが Homebrew, Brewfile パッケージ, シンボリックリンク, vim-plug を自動セットアップ。

セットアップ後:
```bash
vim +PlugInstall +qall                    # Vimプラグイン
$(brew --prefix)/opt/fzf/install          # fzfキーバインド (初回のみ)
```

## ファイル構成

| ファイル | 説明 |
|---|---|
| `.zshrc` | Zsh設定 (ヒストリ, 補完, エイリアス, PATH) |
| `.vimrc` | Vim設定 (プラグイン, キーマップ) |
| `starship.toml` | Starshipプロンプト |
| `Brewfile` | Homebrewパッケージ一覧 |
| `.my_commands/` | 自作コマンド |
| `.vim/` | Vimカラースキーム, vim-plug |
| `set_up.sh` | セットアップスクリプト |

## 自作コマンド (.my_commands/)

| コマンド | 説明 |
|---|---|
| `pokels [-n name] [-t type] [-r region] [-e]` | ポケモン一覧 (種族値付き) |
| `pokefind <name> [-t type] [-r region] [-s stats]` | ポケモン逆引き検索 (日本語/英語, 種族値) |
| `poke [args]` | 壁紙変更+図鑑情報表示。`poke 150` `poke -n gengar` 等 |
| `mka <name> <cmd>` | エイリアスを .zshrc に追加。`mka gs 'git status'` |
| `gccw <file>` | `gcc -Wall -Wextra -Werror` のラッパー |

## 主なエイリアス

| エイリアス | コマンド | 備考 |
|---|---|---|
| `v`, `vi` | vim | |
| `vz` | vim ~/.zshrc | 設定編集用 |
| `vv` | vim ~/.vimrc | 設定編集用 |
| `sovz` | source ~/.zshrc | 設定反映 |
| `g` | git | |
| `d` / `dc` | docker / docker-compose | |
| `cc` | claude | Claude Code |
| `ccc` | claude --continue | 前回セッション継続 |
| `ccr` | claude --resume | セッション再開 |
| `mkcd <dir>` | mkdir + cd | ディレクトリ作成&移動 |

## Vimキーマップ

| キー | 動作 |
|---|---|
| `Ctrl+e` | NERDTree開閉 |
| `Ctrl+n` | ファイル検索 (fzf) |
| `Ctrl+p` | バッファ一覧 (fzf) |
| `Ctrl+z` | 最近開いたファイル (fzf) |
| `Ctrl+g` | grep検索 (ripgrep) |
| `Tab+l/h` | タブ移動 |

## ポケモン背景 (iTerm2)

[Pokemon-Terminal](https://github.com/LazoCoder/Pokemon-Terminal) でiTerm2の背景にポケモンを表示。
Claude Code起動時に `preexec` フックで自動切替。

| 状態 | ポケモン |
|---|---|
| 通常 | ゲンガー |
| Claude Code中 | ミュウツー |

```bash
poke -n gengar   # ゲンガーに変更
poke 150         # ミュウツー
poke             # 全ポケモンからランダム
```

## 更新

```bash
cd ~/my_dotfiles && git pull
brew bundle install --file=Brewfile
vim +PlugUpdate +qall
```

## 必要環境

- macOS (Apple Silicon)
- [Nerd Font](https://www.nerdfonts.com) (アイコン表示用)
