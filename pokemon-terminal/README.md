# Pokemon Terminal v2.0

ピカチュウテーマの mac ターミナル統合スキン。
iTerm2 / Ghostty / LazyVim / Claude Code を 1 つの世界観で繋ぎます。

## 構成

| Phase | 役割 | 主な成果物 |
|-------|------|-----------|
| 0 | 基盤整備 | LazyVim relativenumber 無効化、`pokemon-terminal/` ディレクトリ新設、Brewfile 追加 |
| α | OS Skin | `starship.toml` palette `pokemon` (champion_dark / pika_yellow / gym_red / gym_gold / fire_red)、◉ モンスターボールプロンプト |
| SSOT | Per-session picker | `lib/session-pokemon.sh` がシェル起動毎に1回だけパートナーを選び、`~/.cache/poke-session-current.json` (5フィールド: en/jp/id/type/url) に書き出す。MOTD / Claude statusline は READ ONLY 参照 |
| β | Daily Greeting MOTD | `motd.sh` (SSOT cache を読むだけ) + `data/daily-rotation.json` (15体ローテ、シェル毎に `$RANDOM` で per-session 選出) |
| ~~γ~~ | ~~Living Prompt~~ | **v2.1 で廃止**: krabby silhouette は starship `right_format` の単行制約で表示できなかった。代替: MOTD で pokeget 全身 ASCII を起動時に1回表示。`right_format = "$time"` のみ |
| δ | LazyVim Pokeworld | `nvim/lua/plugins/pokemon.lua` (`:PokemonRandom`)、`dashboard.lua` (起動画面)、`lualine.lua` (⚡ 時計) |
| Claude | Claude Code UI | `claude/statusline.sh` + `claude/session-start.sh` (SSOT cache を mirror、無ければ独自フォールバック) + `pokeclaude` wrapper、`cc` alias 経由 |
| Final | Distribution | `install.sh` + `set_up.sh` 末尾フック + Brewfile (`tap yannjor/krabby` + `krabby`) + `cargo install pokeget` (auto in install.sh) |

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

`data/daily-rotation.json` に定義。シェル起動毎に `$RANDOM` (per-session)
でパートナーを 1 体選出し、その shell の MOTD / starship / Claude statusline で
一貫した表示になります (SSOT は `lib/session-pokemon.sh`)。
新しい iTerm2 タブ / ウィンドウを開くたびにパートナーが変わります。

## ロールバック

### 部分的に戻す

| 戻したい対象 | コマンド |
|--------------|----------|
| SSOT picker のみ | `rm ~/my_dotfiles/pokemon-terminal/lib/session-pokemon.sh && git -C ~/my_dotfiles checkout HEAD -- pokemon-terminal/motd.sh pokemon-terminal/claude/session-start.sh starship.toml .zshrc` |
| starship.toml | `git -C ~/my_dotfiles checkout HEAD -- starship.toml` |
| .zshrc | `git -C ~/my_dotfiles checkout HEAD -- .zshrc` |
| LazyVim plugins | `rm ~/my_dotfiles/nvim/lua/plugins/{pokemon,dashboard,lualine}.lua` |
| LazyVim relativenumber | `git -C ~/my_dotfiles checkout HEAD -- nvim/lua/config/options.lua` |
| Claude statusLine 単体 | `jq 'del(.statusLine)' ~/my_dotfiles/claude/settings.json > /tmp/x && mv /tmp/x ~/my_dotfiles/claude/settings.json` |
| Brewfile (krabby tap) + pokeget | `git -C ~/my_dotfiles checkout HEAD -- Brewfile && brew untap yannjor/krabby && brew uninstall krabby && cargo uninstall pokeget` |
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

# 3. パッケージ削除 (任意)
brew uninstall krabby 2>/dev/null
brew untap yannjor/krabby 2>/dev/null
cargo uninstall pokeget 2>/dev/null

# 4. 反映
source ~/.zshrc
```

## 既知の制約

- `~/.my_commands/poke` (背景画像専用) には触れていません。Living Prompt の `krabby` とは独立動作です
- `pokemon-terminal` Python パッケージのフォルダと名前が衝突します。当ディレクトリは dotfiles 用、画像取得は引き続き `poke` 経由で `pokemon` コマンドが担当します
- Dock icon 置換 / Nerd Font 自作 glyph は今回スコープ外
