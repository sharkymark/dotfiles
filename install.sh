#!/usr/bin/env bash

echo "install.sh"

echo "Copying dotfiles ..."

echo ".gitconfig and .gitignore_global"
cp -r ~/dotfiles/git/.gitconfig ~/dotfiles/git/.gitignore_global ~

echo "copy config.json to code-server directory"
PATH_CS_1="$HOME/.local/share/code-server"
PATH_CS_2="$HOME/.local/share/code-server/User"
PATH_VS_1="$HOME/.config/Code/User"
COMMAND_1="cp ~/dotfiles/Code/User/settings.json ."

if [ -d $PATH_CS_1 ]; then
    if [ -d $PATH_CS_2 ]; then
        echo 'code-server VS Code settings.json already exists'
        $COMMAND_1
    else
        mkdir $PATH_CS_2
        cd $PATH_CS_2
        $COMMAND_1 
    fi
fi

if [ -d $PATH_VS_1 ]; then
    echo 'VS Code settings.json already exists'
    $COMMAND_1 
fi



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


# locations for VS Code settings.json
# Mac $HOME/Library/Application Support/Code/User/
# Linux $HOME/.config/Code/User/