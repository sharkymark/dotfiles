#!/usr/bin/env bash

echo "RUNNING dotfiles repo install.sh"

echo "STEP 1: 💾 copying .gitconfig and .gitignore_global"
cp -r ./git/.gitconfig ./git/.gitignore_global ~


echo "🐚 Shell is $SHELL"
echo "STEP 2: 💾 copying shell configuration files e.g., bash, fish, zsh"

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

