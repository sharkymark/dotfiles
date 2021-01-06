#!/usr/bin/env bash

echo "install.sh"

echo "Copying dotfiles ..."

echo ".gitconfig and .gitignore_global"
cp -r ./dotfiles/git/.gitconfig ./dotfiles/git/.gitignore_global ~