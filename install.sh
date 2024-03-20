#!/usr/bin/env bash

echo "RUNNING dotfiles repo install.sh"

echo "STEP: 💾 copying .gitconfig and .gitignore_global"
cp -r ./git/.gitconfig ./git/.gitignore_global ~



PATH_CS_1="$HOME/.local/share/code-server"
PATH_CS_2="$HOME/.local/share/code-server/User"
PATH_VS_1="$HOME/Library/Application Support/Code/User"
PATH_VSCS_1="$HOME/.vscode-server"
PATH_VSCS_2="$HOME/.vscode-server/data/User"
COMMAND_S="cp ./Code/User/settings.json"
COMMAND_K="cp ./Code/User/keybindings.json"
COMMAND_T="cp ./Code/User/tasks.json"

echo "STEP: copying shell dotfiles e.g., .bashrc, .zshrc"
echo "Shell is $SHELL"

if [ "$SHELL" == "/bin/bash" ]; then 
  cp ./shell/bash/.bashrc $HOME/.bashrc
  cp ./shell/bash/.bash_profile $HOME/.bash_profile  
elif [ "$SHELL" == "/bin/zsh" ]; then
  cp ./shell/zsh/.zshrc $HOME/.zshrc
elif [ "$SHELL" == "/usr/local/fish" ]; then
  cp ./shell/fish/config.fish $HOME/.config/fish/config.fish
else
  echo "no unix shell dotfiles copied"
fi

echo "STEP: copying VS Code-related config files"

if [ -d "$PATH_VSCS_1" ]; then

    echo 'Microsoft VS Code Server found, copying settings.json, keybindings.json, tasks.json'
    if [ -d $PATH_VSCS_2 ]; then        
        echo "$PATH_VSCS_2 found"  
    else
        echo "$PATH_VSCS_2 not found, make directory"
        mkdir "$PATH_VSCS_1"/data/User    
    fi

    $COMMAND_S "$PATH_VSCS_2"
    $COMMAND_K "$PATH_VSCS_2"
    $COMMAND_T "$PATH_VSCS_2"  
fi

echo "before code-server check"

if [ -d $PATH_CS_1 ]; then

    if [ -d $PATH_CS_2 ]; then        
        echo "$PATH_CS_2 found"  
    else
        echo "$PATH_CS_2 not found, make directory"
        mkdir "$PATH_CS_1"/User    
    fi

    # vs code extension installation
    # Check if VS Code is installed by looking for the 'code-server' command
    export EXT_BINARY="/tmp/code-server/bin/code-server"
    if ! command -v $EXT_BINARY &> /dev/null
    then
        echo "code-server is not installed. Please install it before running this script. https://github.com/coder/code-server"
    else
        ./install_vs_code_extensions.sh
    fi

    echo 'code-server found, copying settings.json, keybindings.json, tasks.json'

    $COMMAND_S $PATH_CS_2
    $COMMAND_K $PATH_CS_2
    $COMMAND_T $PATH_CS_2

fi

if [ -d "$PATH_VS_1" ]; then

    # vs code extension installation
    # Check if VS Code is installed by looking for the 'code' command
    export EXT_BINARY="code"
    if ! command -v $EXT_BINARY &> /dev/null
    then
        echo "VS Code is not installed. Please install it before running this script. https://github.com/microsoft/vscode"
    else
        ./install_vs_code_extensions.sh
    fi

    echo 'locally-installed VS Code found, copying settings.json, keybindings.json, tasks.json'
    $COMMAND_S "$PATH_VS_1"
    $COMMAND_K "$PATH_VS_1"
    $COMMAND_T "$PATH_VS_1"  
fi

