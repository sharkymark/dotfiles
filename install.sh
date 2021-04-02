#!/usr/bin/env bash

echo "install.sh"

echo "Copying dotfiles ..."

echo ".gitconfig and .gitignore_global"
cp -r ~/dotfiles/git/.gitconfig ~/dotfiles/git/.gitignore_global ~

echo "install fish shell"

FISH_BINARY=/usr/bin/fish
FISH_PATH=/usr/bin

if [ ! -f $FISH_BINARY ] ; then
    sudo apt-get update
    sudo apt-get install -y fish
    echo "installing fish in $FISH_PATH"
else
    echo "fish already installed"
fi