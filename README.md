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
| 通常 | ダークライ |
| Claude Code中 | ゾロアーク |

```bash
poke -n darkrai  # ダークライに変更
poke 150         # ミュウツー
poke             # 全ポケモンからランダム
```

## Claude Code (`claude/`)

Claude Code の設定一式。`set_up.sh` で `~/.claude/` にシンボリンクが張られる。

| ディレクトリ | 説明 |
|---|---|
| `claude/CLAUDE.md` | グローバル設定（言語・スタック・ワークフロー） |
| `claude/rules/` | コーディング規約（共通 + 10言語） |
| `claude/agents/` | 専門サブエージェント (28個) |
| `claude/skills/` | タスク別リファレンス (48個) |
| `claude/hooks/` | 自動化フック (pre/post-tool) |
| `claude/commands/` | カスタムコマンド |

> 機密ファイル (`settings.local.json`, `mcp-configs/`) は `.gitignore` で除外済み。

### 配置方式

`set_up.sh` は以下のルールで `~/.claude/` にファイルを配置します:

| 対象 | 方式 | 理由 |
|------|------|------|
| `CLAUDE.md`, `settings.json` 等 | ファイル単位シンボリックリンク | 個別管理 |
| `rules/`, `agents/`, `hooks/`, `commands/` | ディレクトリ単位シンボリックリンク | 一括管理 |
| `skills/` | **スキル単位でマージ** | 別リポジトリのスキル（requirements_designer等）を壊さない |

このリポジトリには 28 agents と 48 skills が直接含まれています。一部のスキル（`requirements_designer`, `speckit-bridge` 等）は別リポジトリとして管理され、`~/.claude/skills/` 内に個別のシンボリックリンクが張られます。

## 再実行の安全性（Idempotency）

`set_up.sh` は何度実行しても安全です:

- **Homebrew**: `command -v brew` で存在チェック、インストール済みならスキップ
- **Brewfile**: `brew bundle install` は冪等（インストール済みパッケージはスキップ）
- **シンボリックリンク**: 既存リンクは削除→再作成、通常ファイルはタイムスタンプ付きバックアップ後にリンク作成
- **ディレクトリ**: `mkdir -p` で既存なら何もしない
- **vim-plug**: 存在チェック後にインストール
- **iTerm2**: アプリ存在チェック後にセットアップ

`git pull` 後に再実行することで、設定の更新を安全に適用できます。

## 更新

```bash
cd ~/my_dotfiles && git pull
brew bundle install --file=Brewfile
vim +PlugUpdate +qall
```

## 必要環境

- macOS (Apple Silicon)
- [Nerd Font](https://www.nerdfonts.com) (アイコン表示用)
