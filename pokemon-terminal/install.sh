#!/usr/bin/env bash
# Pokemon Terminal v2.0 installer
set -e
DOTFILES="$HOME/my_dotfiles"

echo "📦 Installing Pokemon Terminal v2.0..."

# Brewfile 経由のツール
brew bundle --file="$DOTFILES/Brewfile" 2>/dev/null || true

# pokeget: brew formula が存在しないため cargo 経由で install
# (cargo が無ければ skip、~/.cargo/bin は .zshrc で PATH 追加済)
if command -v cargo >/dev/null 2>&1; then
  if ! command -v pokeget >/dev/null 2>&1 && [[ ! -x "$HOME/.cargo/bin/pokeget" ]]; then
    echo "🦀 Installing pokeget via cargo..."
    cargo install pokeget --quiet 2>/dev/null || echo "⚠ pokeget cargo install failed (non-fatal)"
  fi
fi

# 実行権限
chmod +x "$DOTFILES/pokemon-terminal/motd.sh" 2>/dev/null
chmod +x "$DOTFILES/pokemon-terminal/pokeclaude" 2>/dev/null
chmod +x "$DOTFILES/pokemon-terminal/claude/"*.sh 2>/dev/null
chmod +x "$DOTFILES/pokemon-terminal/lib/"*.sh 2>/dev/null

echo "✅ Pokemon Terminal v2.0 installed."
echo "💡 Restart shell or run: source ~/.zshrc"
