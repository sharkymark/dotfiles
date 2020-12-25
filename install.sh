#!/usr/bin/env bash

echo "Hello install.sh"

echo "Clon-ing dotfiles..."
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Install HOME-based bash files
#ln -s $DIR/bash/.bash_aliases $HOME
#ln -s $DIR/bash/.bash_path $HOME
#ln -s $DIR/bash/.bashrc $HOME
#ln -s $DIR/bash/.profile $HOME

# Install git files
ln -s $DIR/git/.gitconfig $HOME

# Install VS Code files
mkdir -p $HOME/.config/Code/User
ln -s $DIR/Code/User/keybindings.json $HOME/.config/Code/User