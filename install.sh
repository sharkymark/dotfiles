#!/usr/bin/env bash

echo "install.sh"

echo "Copying dotfiles ..."

echo "STEP: .gitconfig and .gitignore_global"
cp -r ./git/.gitconfig ./git/.gitignore_global ~

echo "STEP: copy config.json to code-server directory"
PATH_CS_1="$HOME/.local/share/code-server"
PATH_CS_2="$HOME/.local/share/code-server/User"
PATH_VS_1="$HOME/Library/Application Support/Code/User"
COMMAND_S="cp ./Code/User/settings.json"
COMMAND_K="cp ./Code/User/settings.json"

if [ -d $PATH_CS_1 ]; then
    echo 'code-server folder exists, copying settings.json and keybindings.json'
    if [ -d $PATH_CS_2 ]; then
    echo "User directory found"
        $COMMAND_S $PATH_CS_2
        $COMMAND_K $PATH_CS_2
    else
        echo "User directory not found, make directory"
        mkdir "$PATH_CS_1"/User
        $COMMAND_S $PATH_CS_2
        $COMMAND_K $PATH_CS_2
    fi
fi

if [ -d "$PATH_VS_1" ]; then
    echo 'VS Code exists, copying settings.json and keybindings.json'
    $COMMAND_S "$PATH_VS_1"
    $COMMAND_K "$PATH_VS_1"
fi



echo "STEP: install fish shell ( check OS )"

FISH_BINARY=/usr/bin/fish
FISH_PATH=/usr/bin

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ ! -f $FISH_BINARY ] ; then
        echo "installing fish in $FISH_PATH"
        if [ -f "/etc/arch-release" ]; then
            sudo pacman -S fish --noconfirm
            echo "Arch Linux"
        elif [ -f "/etc/lsb-release" ]; then
            sudo apt-get update
            sudo apt-get install -y fish  
            echo "Ubuntu" 
        fi
    else
        echo "fish already installed"
    fi
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install fish
    echo "MacOS Darwin with brew"
fi 


# locations for VS Code settings.json
# Mac $HOME/Library/Application Support/Code/User/
# Linux $HOME/.config/Code/User/
# locations for code-server settings.json
# $HOME/.local/share/code-server/User