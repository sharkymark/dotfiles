#!/usr/bin/env bash

echo "dotfiles repo install.sh"

echo "Copying dotfiles ..."

echo "STEP: copying .gitconfig and .gitignore_global"
cp -r ./git/.gitconfig ./git/.gitignore_global ~


PATH_CS_1="$HOME/.local/share/code-server"
PATH_CS_2="$HOME/.local/share/code-server/User"
PATH_VS_1="$HOME/Library/Application Support/Code/User"
COMMAND_S="cp ./Code/User/settings.json"
COMMAND_K="cp ./Code/User/keybindings.json"
COMMAND_T="cp ./Code/User/tasks.json"

echo "STEP: copying shell dotfiles e.g., .bashrc, .zshrc"

if [ "$SHELL" == "/bin/bash" ]; then
  cp /shell/bash/.bashrc $HOME/.bashrc
elif [ "$SHELL" == "/bin/zsh" ]; then
  cp /shell/zsh/.zshrc $HOME/.zshrc
elif [ "$SHELL" == "/usr/local/fish" ]; then
  cp /shell/fish/config.fish $HOME/.config/fish/config.fish
else
  echo "no unix shell dotfiles copied"
fi

echo "STEP: copying VS Code-related config files"

if [ -d $PATH_CS_1 ]; then

    echo 'code-server directory exists (i.e., a Coder remote workspace), copying settings.json, keybindings.json, tasks.json' 
    if [ -d $PATH_CS_2 ]; then        
        echo "User directory found"  
    else
        echo "User directory not found, make directory"
        #mkdir "$PATH_CS_1/User"    
    fi

    $COMMAND_S $PATH_CS_2
    $COMMAND_K $PATH_CS_2
    $COMMAND_T $PATH_CS_2

fi

if [ -d "$PATH_VS_1" ]; then
    echo 'locally-installed VS Code found, copying settings.json, keybindings.json, tasks.json'
    $COMMAND_S "$PATH_VS_1"
    $COMMAND_K "$PATH_VS_1"
    $COMMAND_T "$PATH_VS_1"  
fi