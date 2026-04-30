# ==========================================================
# Brewfile - macOS パッケージ管理
# Usage: brew bundle install --file=~/my_dotfiles/Brewfile
# ==========================================================

# ── Taps ──────────────────────────────────────────────────
tap "homebrew/cask-fonts"
tap "yannjor/krabby"             # Pokemon Terminal v2.0 community tap (krabby formula)

# ── CLI ツール ────────────────────────────────────────────
brew "vim"                       # レガシーフォールバック
brew "neovim"                    # メインエディタ (LazyVim)
brew "starship"
brew "fzf"                   # ファジーファインダー (Vim + シェルで使用)
brew "ripgrep"               # 高速grep (fzf.vimの:Rgで使用)
brew "bat"                       # catの代替 (シンタックスハイライト付き)
brew "fd"                        # Telescope ファイル検索用 (find より高速)
brew "lazygit"                   # LazyVim の Git UI 統合

# ── Git ───────────────────────────────────────────────────
brew "git"

# ── 言語バージョン管理 ───────────────────────────────────
brew "pyenv"
brew "nodebrew"
# brew "volta"               # nodebrewの代替 (より高速)

# ── クラウド / インフラ ──────────────────────────────────
brew "awscli"
brew "kubernetes-cli"
cask "gcloud-cli"

# ── データベース ──────────────────────────────────────────
brew "mysql"

# ── その他 ────────────────────────────────────────────────
brew "yarn"
brew "cocoapods"

# ── フォント (Nerd Font - Starship/Vim-devicons用) ───────
cask "font-hack-nerd-font"

# ── Pokemon Terminal v2.0 ────────────────────────────────
# krabby: pre-rendered ASCII silhouette for starship right_format (per-session SSOT)
brew "krabby"       # via yannjor/krabby tap (above)

# pokeget: MOTD greeting image. No working brew formula exists; install via cargo.
# After running `brew bundle install`, also run: cargo install pokeget
# (PATH `~/.cargo/bin` is wired in .zshrc — see cargo block)
