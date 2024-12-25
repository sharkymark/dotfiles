#!/bin/bash

echo "RUNNING dotfiles repo install.sh"

echo "STEP 1: 💾 copying .gitconfig and .gitignore_global"
cp -r ./git/.gitconfig ./git/.gitignore_global ~


echo "🐚 shell is $SHELL"
echo "STEP 2: 💾 about to copy shell configuration files e.g., bash, fish, zsh"

# Check for bash
if [ "$SHELL" == "/bin/bash" ]; then
  cp ./shell/bash/.bashrc $HOME/.bashrc
  cp ./shell/bash/.bash_profile $HOME/.bash_profile
  echo "Copied bash 👾 configuration files to $HOME"
fi

# Check for zsh
if [ "$SHELL" == "/bin/zsh" ]; then
  cp ./shell/zsh/.zshrc $HOME/.zshrc
  echo "💾 copied zsh 🍎 configuration files to $HOME"
fi

# Check for fish (regardless of current shell)
if command -v fish &> /dev/null; then
  cp ./shell/fish/config.fish $HOME/.config/fish/config.fish
  echo "💾 copied fish 🐟 configuration files to $HOME/.config/fish"
fi

# If none of the above conditions are met, print a message
if [ "$SHELL" != "/bin/bash" ] && [ "$SHELL" != "/bin/zsh" ] && ! command -v fish &> /dev/null; then
  echo "No unix shell dotfiles copied. Please ensure you have bash, zsh, or fish installed."
fi

