#!/usr/bin/env bash
# Pokemon Terminal v2.0 installer
set -e
DOTFILES="$HOME/my_dotfiles"

echo "📦 Installing Pokemon Terminal v2.0..."

# Brewfile 経由のツール
brew bundle --file="$DOTFILES/Brewfile" 2>/dev/null || true

# 実行権限
chmod +x "$DOTFILES/pokemon-terminal/motd.sh" 2>/dev/null
chmod +x "$DOTFILES/pokemon-terminal/pokeclaude" 2>/dev/null
chmod +x "$DOTFILES/pokemon-terminal/claude/"*.sh 2>/dev/null

echo "✅ Pokemon Terminal v2.0 installed."
echo "💡 Restart shell or run: source ~/.zshrc"
