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
  brew bundle install --file="$DOTPATH/Brewfile"
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
    # 既にシンボリックリンクなら削除して再作成（macOS ln -snf のディレクトリ入れ子バグ回避）
    rm "$dst"
    ln -sv "$src" "$dst"
  elif [[ -e "$dst" ]]; then
    warn "$dst は既に存在します (シンボリックリンクではありません)。バックアップを作成します。"
    mv "$dst" "${dst}.backup.$(date +%Y%m%d%H%M%S)"
    ln -sv "$src" "$dst"
  else
    ln -sv "$src" "$dst"
  fi
}

link_file "$DOTPATH/.vimrc"         "$HOME/.vimrc"
link_file "$DOTPATH/.zshrc"         "$HOME/.zshrc"
link_file "$DOTPATH/starship.toml"  "$HOME/.config/starship.toml"
link_file "$DOTPATH/.my_commands"   "$HOME/.my_commands"
link_file "$DOTPATH/.vim"           "$HOME/.vim"

info "シンボリックリンク作成完了"

# ── 5. Claude Code 設定 ───────────────────────────────────
CLAUDE_SRC="$DOTPATH/claude"
CLAUDE_DST="$HOME/.claude"

if [[ -d "$CLAUDE_SRC" ]]; then
  echo "Claude Code 設定をセットアップします..."
  mkdir -p "$CLAUDE_DST"

  # ファイル単位でシンボリックリンク（既存の動的ファイルを壊さない）
  for item in CLAUDE.md AGENTS.md settings.json plugin.json marketplace.json \
              README.md PLUGIN_SCHEMA_NOTES.md .gitignore; do
    if [[ -f "$CLAUDE_SRC/$item" ]]; then
      link_file "$CLAUDE_SRC/$item" "$CLAUDE_DST/$item"
    fi
  done

  # ディレクトリ単位でシンボリックリンク（skills は除外: ランタイムで追加されるスキルがあるため）
  for dir in rules agents hooks commands scripts; do
    if [[ -d "$CLAUDE_SRC/$dir" ]]; then
      link_file "$CLAUDE_SRC/$dir" "$CLAUDE_DST/$dir"
    fi
  done

  # skills はファイル単位でマージ（既存のシンボリンクスキルを壊さない）
  if [[ -d "$CLAUDE_SRC/skills" ]]; then
    mkdir -p "$CLAUDE_DST/skills"
    for skill_dir in "$CLAUDE_SRC/skills"/*/; do
      skill_name=$(basename "$skill_dir")
      link_file "$skill_dir" "$CLAUDE_DST/skills/$skill_name"
    done
  fi

  # settings.local.json のテンプレートをコピー（既存がなければ）
  if [[ -f "$CLAUDE_SRC/settings.local.template.json" ]] && [[ ! -f "$CLAUDE_DST/settings.local.json" ]]; then
    cp "$CLAUDE_SRC/settings.local.template.json" "$CLAUDE_DST/settings.local.json"
    warn "settings.local.json をテンプレートからコピーしました。\$HOME パスを実際の値に置換してください"
  fi

  info "Claude Code 設定完了"
else
  warn "claude/ ディレクトリが見つかりません。Claude Code セットアップをスキップします。"
fi

# ── 5b. 自作スキルリポジトリの clone ─────────────────────
clone_skill_repo() {
  local repo="$1" dest="$2"
  if [[ -d "$dest" ]]; then
    info "$dest は既に存在 — スキップ"
  else
    echo "  Cloning $repo → $dest"
    git clone "git@github.com:$repo.git" "$dest" || warn "Clone failed: $repo — SSH キー未設定の可能性。後で手動実行してください"
  fi
}

echo "自作スキルリポジトリを clone します..."

# ~/.claude/skills/ 内に直接 clone
clone_skill_repo "fideguch/bochi"             "$CLAUDE_DST/skills/bochi"
clone_skill_repo "fideguch/pm_data_analysis"  "$CLAUDE_DST/skills/pm-data-analysis"
clone_skill_repo "fideguch/speckit-bridge"    "$CLAUDE_DST/skills/speckit-bridge"

# 別ディレクトリに clone → symlink
clone_skill_repo "fideguch/pm_ad_analysis"    "$HOME/pm_ad_analysis"
if [[ ! -e "$CLAUDE_DST/skills/pm-ad-analysis" ]]; then
  ln -sv "$HOME/pm_ad_analysis" "$CLAUDE_DST/skills/pm-ad-analysis"
fi

clone_skill_repo "fideguch/google-workspace"  "$HOME/google_mcps"
if [[ ! -e "$CLAUDE_DST/skills/google-workspace" ]]; then
  ln -sv "$HOME/google_mcps/google-workspace" "$CLAUDE_DST/skills/google-workspace"
fi

# requirements_designer は npx skills add 経由でインストール
# 詳細は claude/INSTALL_SKILLS.md を参照

info "自作スキル clone 完了"

# ── 6. Vim プラグインのインストール ──────────────────────
if [[ -f "$HOME/.vim/autoload/plug.vim" ]]; then
  info "vim-plug は既にインストール済み"
else
  echo "vim-plug をインストールします..."
  curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  info "vim-plug インストール完了"
fi

# ── 7. iTerm2 Pokemon プロファイル ─────────────────────────
if [[ -d "/Applications/iTerm.app" ]]; then
  echo "iTerm2 Pokemon プロファイルをセットアップします..."
  "$DOTPATH/.my_commands/setup-pokemon-iterm"
  if ! command -v pokemon &>/dev/null; then
    warn "pokemon-terminal が未インストール。背景画像を使うにはインストールしてください:"
    warn "  pip3 install --user git+https://github.com/LazoCoder/Pokemon-Terminal.git"
  fi
else
  warn "iTerm2 が見つかりません。Pokemon プロファイルのセットアップをスキップします。"
fi

echo ""
echo "セットアップ完了！ 以下を実行してください:"
echo "  1. ターミナルを再起動するか: source ~/.zshrc"
echo "  2. Vimを開いて :PlugInstall を実行"
echo "  3. iTerm2 で Pokemon プロファイルをデフォルトに設定"
echo "  4. Claude Code 外部スキルをインストール: cat ~/my_dotfiles/claude/INSTALL_SKILLS.md"
echo "  5. settings.local.json のプレースホルダーを実際の値に置換"
echo ""
