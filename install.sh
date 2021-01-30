#!/bin/sh

DOTPATH=~/dotfiles

for f in .??*
do
    [[ "$f" == ".git" ]] && continue
    [[ "$f" == ".DS_Store" ]] && continue

    echo "$f"
    ln -snfv "$DOTPATH/$f" "$HOME"/"$f"
done
