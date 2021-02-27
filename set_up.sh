#!/bin/sh

DOTPATH=$HOME/dotfiles
ln -snfv "$DOTPATH/.vimrc" "$HOME"/".vimrc"
ln -snfv "$DOTPATH/.zshrc" "$HOME"/".zshrc"
ln -snfv "$DOTPATH/starship.toml" "$HOME"/".config"/"starship.toml"
ln -snfv "$DOTPATH/.my_commands" "$HOME"/".my_commands"
