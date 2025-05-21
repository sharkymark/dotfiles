#!/bin/bash

echo "Setting up Homebrew..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install packages from Brewfile if it exists
if [ -f "$DOTFILES_PATH/brew/Brewfile" ]; then
  echo "Installing/Upgrading packages from Brewfile (only upgraded will be shown)..."
  brew bundle --file="$DOTFILES_PATH/brew/Brewfile" | grep "Upgrading"
else
  echo "Brewfile not found."
fi

echo "Homebrew setup complete."