# Pokemon Terminal v2.0

ピカチュウテーマの mac ターミナル統合スキン。
iTerm2 / Ghostty / LazyVim / Claude Code を 1 つの世界観で繋ぎます。

## 構成

| Phase | 役割 | 主な成果物 |
|-------|------|-----------|
| 0 | 基盤整備 | LazyVim relativenumber 無効化、`pokemon-terminal/` ディレクトリ新設、Brewfile 追加 |
| α | OS Skin | `starship.toml` palette `pokemon` (champion_dark / pika_yellow / gym_red / gym_gold / fire_red)、◉ モンスターボールプロンプト |
| β | Daily Greeting MOTD | `motd.sh` + `data/daily-rotation.json` (15体ローテ、`date +%j` seed) |
| γ | Living Prompt | starship `[custom.pokemon]` で `krabby random` を `right_format` に表示 |
| δ | LazyVim Pokeworld | `nvim/lua/plugins/pokemon.lua` (`:PokemonRandom`)、`dashboard.lua` (起動画面)、`lualine.lua` (⚡ 時計) |
| Claude | Claude Code UI | `claude/statusline.sh` + `claude/session-start.sh` + `pokeclaude` wrapper、`cc` alias 経由 |
| Final | Distribution | `install.sh` + `set_up.sh` 末尾フック + Brewfile 追加 (`pokeget-rs`, `krabby`) |

## 使い方

### 初期セットアップ

```bash
bash ~/my_dotfiles/pokemon-terminal/install.sh
source ~/.zshrc
```

### 日々の操作

| コマンド | 効果 |
|----------|------|
| 新規シェル起動 | ランダム背景 + 今日のパートナー MOTD |
| `poke -n garchomp` | 背景画像をガブリアスに変更 |
| `cc` | Pokemon Claude wrapper (起動時パートナー表示) |
| `nvim` 起動 | ピカチュウダッシュボード + ⚡ 時計 lualine |
| `:PokemonRandom` | LazyVim 内でランダムポケモンを表示 |

### 今日のパートナー (15体ローテ)

`data/daily-rotation.json` に定義。`date +%j` (年通算日) をシードとし、
1日固定で同じパートナーが選ばれます。

## ロールバック

### 部分的に戻す

| 戻したい対象 | コマンド |
|--------------|----------|
| starship.toml | `git -C ~/my_dotfiles checkout HEAD -- starship.toml` |
| .zshrc | `git -C ~/my_dotfiles checkout HEAD -- .zshrc` |
| LazyVim plugins | `rm ~/my_dotfiles/nvim/lua/plugins/{pokemon,dashboard,lualine}.lua` |
| LazyVim relativenumber | `git -C ~/my_dotfiles checkout HEAD -- nvim/lua/config/options.lua` |
| Claude statusLine 単体 | `jq 'del(.statusLine)' ~/my_dotfiles/claude/settings.json > /tmp/x && mv /tmp/x ~/my_dotfiles/claude/settings.json` |
| Brewfile (pokeget/krabby) | `git -C ~/my_dotfiles checkout HEAD -- Brewfile && brew uninstall pokeget-rs krabby` |
| 1 セッション分のみ無効化 | `unalias cc && export _POKE_DONE=1 _POKE_MOTD_DONE=1` |

### 完全アンインストール

```bash
cd ~/my_dotfiles
# 1. 編集ファイルを HEAD に戻す
git checkout HEAD -- .zshrc Brewfile README.md claude/settings.json \
  nvim/lua/config/options.lua set_up.sh starship.toml

# 2. 新規ファイルを削除
rm -rf pokemon-terminal/
rm -f nvim/lua/plugins/{dashboard,lualine,pokemon}.lua

# 3. brew パッケージ削除 (任意)
brew uninstall pokeget-rs krabby 2>/dev/null

# 4. 反映
source ~/.zshrc
```

## 既知の制約

- `~/.my_commands/poke` (背景画像専用) には触れていません。Living Prompt の `krabby` とは独立動作です
- `pokemon-terminal` Python パッケージのフォルダと名前が衝突します。当ディレクトリは dotfiles 用、画像取得は引き続き `poke` 経由で `pokemon` コマンドが担当します
- Dock icon 置換 / Nerd Font 自作 glyph は今回スコープ外
