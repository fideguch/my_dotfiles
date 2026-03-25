#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# dotfiles セットアップスクリプト
# Usage: cd ~/my_dotfiles && ./set_up.sh
# ==========================================================

DOTPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── カラー出力 ────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'
info()    { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERR]${RESET} $*" >&2; }

# ── 1. Homebrew ───────────────────────────────────────────
if command -v brew &>/dev/null; then
  info "Homebrew は既にインストール済み"
else
  echo "Homebrew をインストールします..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  info "Homebrew インストール完了"
fi

# ── 2. Brewfile からパッケージをインストール ──────────────
if [[ -f "$DOTPATH/Brewfile" ]]; then
  echo "Brewfile からパッケージをインストールします..."
  brew bundle install --file="$DOTPATH/Brewfile" --no-lock
  info "パッケージインストール完了"
else
  warn "Brewfile が見つかりません。スキップします。"
fi

# ── 3. 必要なディレクトリを作成 ──────────────────────────
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.vimbackup"
mkdir -p "$HOME/.zsh/cache"

# ── 4. シンボリックリンクを作成 ──────────────────────────
link_file() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    # 既にシンボリックリンクなら張り直し
    ln -snfv "$src" "$dst"
  elif [[ -e "$dst" ]]; then
    warn "$dst は既に存在します (シンボリックリンクではありません)。バックアップを作成します。"
    mv "$dst" "${dst}.backup.$(date +%Y%m%d%H%M%S)"
    ln -snfv "$src" "$dst"
  else
    ln -snfv "$src" "$dst"
  fi
}

link_file "$DOTPATH/.vimrc"         "$HOME/.vimrc"
link_file "$DOTPATH/.zshrc"         "$HOME/.zshrc"
link_file "$DOTPATH/starship.toml"  "$HOME/.config/starship.toml"
link_file "$DOTPATH/.my_commands"   "$HOME/.my_commands"
link_file "$DOTPATH/.vim"           "$HOME/.vim"

info "シンボリックリンク作成完了"

# ── 5. Vim プラグインのインストール ──────────────────────
if [[ -f "$HOME/.vim/autoload/plug.vim" ]]; then
  info "vim-plug は既にインストール済み"
else
  echo "vim-plug をインストールします..."
  curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  info "vim-plug インストール完了"
fi

# ── 6. iTerm2 Pikachu プロファイル ────────────────────────
if [[ -d "/Applications/iTerm.app" ]]; then
  echo "iTerm2 Pikachu プロファイルをセットアップします..."
  if command -v pokemon &>/dev/null; then
    "$DOTPATH/.my_commands/setup-pikachu-iterm"
  else
    warn "pokemon-terminal が未インストール。先にインストールしてください:"
    warn "  pip3 install --user git+https://github.com/LazoCoder/Pokemon-Terminal.git"
    warn "  その後: setup-pikachu-iterm"
  fi
else
  warn "iTerm2 が見つかりません。Pikachu プロファイルのセットアップをスキップします。"
fi

echo ""
echo "セットアップ完了！ 以下を実行してください:"
echo "  1. ターミナルを再起動するか: source ~/.zshrc"
echo "  2. Vimを開いて :PlugInstall を実行"
echo "  3. iTerm2 で Pikachu プロファイルをデフォルトに設定"
echo ""
