#!/usr/bin/env bash

echo "install.sh"

echo "Copying dotfiles ..."

echo ".gitconfig and .gitignore_global"
cp -r ./git/.gitconfig ./git/.gitignore_global ~