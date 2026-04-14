# my_dotfiles

macOS (Apple Silicon) 用の個人dotfiles。zsh, Neovim (LazyVim), Starship を中心としたターミナル環境。

## セットアップ

```bash
git clone https://github.com/fideguch/my_dotfiles.git ~/my_dotfiles
cd ~/my_dotfiles
chmod +x set_up.sh
./set_up.sh
```

スクリプトが Homebrew, Brewfile パッケージ, シンボリックリンク, LazyVim, vim-plug を自動セットアップ。

セットアップ後:
```bash
nvim                                      # LazyVim 初回起動 (プラグイン自動インストール)
$(brew --prefix)/opt/fzf/install          # fzfキーバインド (初回のみ)
```

## ファイル構成

| ファイル | 説明 |
|---|---|
| `.zshrc` | Zsh設定 (ヒストリ, 補完, エイリアス, PATH) |
| `nvim/` | **Neovim (LazyVim) 設定** (メインエディタ) |
| `.vimrc` | Vim設定 (レガシーフォールバック) |
| `starship.toml` | Starshipプロンプト |
| `Brewfile` | Homebrewパッケージ一覧 |
| `.my_commands/` | 自作コマンド |
| `.vim/` | Vimカラースキーム, vim-plug |
| `ghostty/` | Ghostty/cmux 設定 (Japanesque テーマ, フォント, キーバインド) |
| `cmux/` | cmux macOS defaults スクリプト |
| `iterm2/` | iTerm2 Pokemon プロファイル |
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
| `v`, `vi` | nvim | メインエディタ |
| `vz` | nvim ~/.zshrc | 設定編集用 |
| `vv` | nvim ~/.vimrc | 設定編集用 |
| `vn` | nvim ~/my_dotfiles/nvim/ | LazyVim設定編集 |
| `oldvim` | command vim | 旧Vimフォールバック |
| `sovz` | source ~/.zshrc | 設定反映 |
| `g` | git | |
| `d` / `dc` | docker / docker-compose | |
| `cc` | claude | Claude Code |
| `ccc` | claude --continue | 前回セッション継続 |
| `ccr` | claude --resume | セッション再開 |
| `ccf` | claude --dangerously-skip-permissions | 権限スキップ |
| `ccp` | claude --print | 非対話モード |
| `mkcd <dir>` | mkdir + cd | ディレクトリ作成&移動 |

## エディタキーマップ

Neovim (LazyVim) と旧Vimで同じキーバインドが使える（筋肉記憶移行済み）。

| キー | 動作 | Neovim | 旧Vim |
|---|---|---|---|
| `Ctrl+e` | ファイルツリー開閉 | Neo-tree | NERDTree |
| `Ctrl+n` | ファイル検索 | Telescope | fzf |
| `Ctrl+p` | バッファ一覧 | Telescope | fzf |
| `Ctrl+z` | 最近開いたファイル | Telescope | fzf |
| `Ctrl+g` | grep検索 | Telescope (live_grep) | fzf (ripgrep) |
| `Tab+l/h` | タブ移動 | 共通 | 共通 |

### LazyVim 固有キー

| キー | 動作 |
|---|---|
| `Space` | which-key メニュー (全操作の入口) |
| `<leader>gg` | lazygit 起動 |
| `<leader>ha` / `<leader>1-4` | Harpoon (ファイル高速ジャンプ) |
| `<leader>pk` | ポケモン背景変更 |
| `gd` / `gr` / `K` | 定義ジャンプ / 参照一覧 / ホバードキュメント (LSP) |
| `<leader>cf` | ファイルフォーマット |

## ポケモン背景 (iTerm2 / cmux / Neovim)

[Pokemon-Terminal](https://github.com/LazoCoder/Pokemon-Terminal) でターミナル背景にポケモンを表示。
ターミナル起動時に厳選22匹からランダムで1匹を設定。

```bash
poke -n gliscor  # グライオンに変更
poke 150         # ミュウツー
poke             # 全ポケモンからランダム
poke --clear     # 背景クリア (cmux のみ)
```

`poke` は `$TERM_PROGRAM` でバックエンドを自動判別:

| ターミナル | バックエンド |
|-----------|------------|
| iTerm2 | AppleScript (pokemon-terminal) |
| cmux (Ghostty) | Kitty graphics protocol (z=-1, テキストの後ろに表示) |

cmux ではウィンドウリサイズ時に `.zshrc` の `TRAPWINCH` が自動的に再描画する。

### Neovim 統合

Neovim (LazyVim) はカラースキーム (catppuccin-mocha) の `transparent_background = true` 設定により、ターミナルのポケモン背景がエディタ内で透けて見える。起動時のダッシュボードに現在のポケモン名を表示。`<leader>pk` でNeovim内からポケモン変更も可能。

> Claude Code セッション中も `poke` コマンドで随時変更可能。

## Claude Code (`claude/`)

Claude Code の設定一式。`set_up.sh` で `~/.claude/` にシンボリックリンクが張られる。

| ディレクトリ | 説明 |
|---|---|
| `claude/CLAUDE.md` | グローバル設定（言語・スタック・ワークフロー） |
| `claude/rules/` | コーディング規約（共通 + 10言語） |
| `claude/agents/` | 専門サブエージェント (28個) |
| `claude/skills/` | タスク別リファレンス (48個) |
| `claude/hooks/` | 自動化フック (pre/post-tool) |
| `claude/commands/` | カスタムコマンド |

> 機密ファイル (`settings.local.json`, `mcp-configs/`) は `.gitignore` で除外済み。
> テンプレートは `claude/settings.local.template.json` を参照。

### 3層構成

Claude Code 環境は以下の3層で管理される。新しいマシンでは `set_up.sh` 実行後、Layer 3 の手動インストールが必要。

**Layer 1: dotfiles (このリポジトリ)** -- `set_up.sh` でシンボリックリンク

ECC (Everything Claude Code) 由来スキル、rules、agents、commands、hooks を含む。このリポジトリには 28 agents と 48 skills が直接含まれている。

**Layer 2: 自作 GitHub リポジトリ** -- `set_up.sh` で自動 clone

`set_up.sh` が `fideguch/` 配下の自作スキルリポジトリを clone し、`~/.claude/skills/` に配置する。

| スキル | リポジトリ | 配置先 |
|--------|-----------|--------|
| bochi | fideguch/bochi | `~/.claude/skills/bochi` (直接 clone) |
| pm-data-analysis | fideguch/pm_data_analysis | `~/.claude/skills/pm-data-analysis` (直接 clone) |
| pm-ad-analysis | fideguch/pm_ad_analysis | `~/pm_ad_analysis` → symlink |
| speckit-bridge | fideguch/speckit-bridge | `~/.claude/skills/speckit-bridge` (直接 clone) |
| requirements_designer | fideguch/requirements_designer | `~/.agents/skills/` → npx skills 経由 |
| google-workspace | fideguch/google-workspace | `~/google_mcps` → symlink |

> 注: `pm-ad-operations` は `pm-ad-analysis` に統合済み。単独スキルとしては存在しない。

**Layer 3: 外部スキル** -- 手動インストール (`INSTALL_SKILLS.md` 参照)

`npx skills add` でインストールする PM スキル群 (45+)、Vercel Labs スキル、公式プラグイン (skill-creator, discord) 等。詳細は `claude/INSTALL_SKILLS.md` を参照。

### 配置方式

`set_up.sh` は以下のルールで `~/.claude/` にファイルを配置する:

| 対象 | 方式 | 理由 |
|------|------|------|
| `CLAUDE.md`, `settings.json` 等 | ファイル単位シンボリックリンク | 個別管理 |
| `rules/`, `agents/`, `hooks/`, `commands/` | ディレクトリ単位シンボリックリンク | 一括管理 |
| `skills/` | **スキル単位でマージ** | Layer 2/3 のスキルを壊さない |

## 再実行の安全性（Idempotency）

`set_up.sh` は何度実行しても安全です:

- **Homebrew**: `command -v brew` で存在チェック、インストール済みならスキップ
- **Brewfile**: `brew bundle install` は冪等（インストール済みパッケージはスキップ）
- **シンボリックリンク**: 既存リンクは削除→再作成、通常ファイルはタイムスタンプ付きバックアップ後にリンク作成
- **ディレクトリ**: `mkdir -p` で既存なら何もしない
- **vim-plug**: 存在チェック後にインストール
- **Neovim/LazyVim**: `nvim/` をシンボリックリンク、ヘッドレスで `Lazy! sync` 実行（失敗してもスクリプト中断なし）
- **Ghostty/cmux**: config はコピー、background はシードコピー（ランタイム状態）、cmux defaults はスクリプト実行
- **iTerm2**: アプリ存在チェック後にセットアップ

`git pull` 後に再実行することで、設定の更新を安全に適用できます。

## 更新

```bash
cd ~/my_dotfiles && git pull
brew bundle install --file=Brewfile
nvim --headless "+Lazy! sync" +qa        # LazyVim プラグイン更新
vim +PlugUpdate +qall                    # 旧Vim プラグイン更新 (任意)
```

## 必要環境

- macOS (Apple Silicon)
- [Nerd Font](https://www.nerdfonts.com) (アイコン表示用)
- ターミナル: [cmux](https://www.cmux.dev/) (推奨) または [iTerm2](https://iterm2.com/)
- ポケモン背景: `pip3 install --user git+https://github.com/LazoCoder/Pokemon-Terminal.git`
