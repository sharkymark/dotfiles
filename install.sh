#!/usr/bin/env bash

echo "install.sh"

echo "Copying dotfiles ..."

echo "STEP: .gitconfig and .gitignore_global"
cp -r ./git/.gitconfig ./git/.gitignore_global ~

echo "STEP: copy config.json to code-server directory"
PATH_APPS="/coder/apps"
PATH_CS_1="$HOME/.local/share/code-server"
PATH_CS_2="$HOME/.local/share/code-server/User"
PATH_VS_1="$HOME/Library/Application Support/Code/User"
COMMAND_S="cp ./Code/User/settings.json"
COMMAND_K="cp ./Code/User/keybindings.json"
COMMAND_T="cp ./Code/User/tasks.json"

# cp ./coder/.bashrc $HOME

if [ -d $PATH_CS_1 ]; then

    echo 'code-server folder exists, copying settings.json and keybindings.json' 
    if [ -d $PATH_CS_2 ]; then
        echo "User directory found"              
    else
        echo "User directory not found, make directory"
        mkdir "$PATH_CS_1"/User    
    fi

    # copy settings, keybindings and tasks.json
    $COMMAND_S $PATH_CS_2
    echo "settings.json copied"
    $COMMAND_K $PATH_CS_2
    echo "keybindings.json copied"
    $COMMAND_T $PATH_CS_2
    echo "tasks.json copied"

fi

if [ -d "$PATH_VS_1" ]; then
    echo 'VS Code exists, copying settings.json and keybindings.json'
    $COMMAND_S "$PATH_VS_1"
    echo "settings.json copied"
    $COMMAND_K "$PATH_VS_1"
    echo "keybindings.json copied"
    $COMMAND_T "$PATH_VS_1"
    echo "tasks.json copied"    
fi