#!/bin/bash

echo "Setting up Homebrew package manager..."
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "📦 Homebrew not installed - installing now..."
  echo "   (This may take a few minutes)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "✅ Homebrew installed successfully!"
else
  echo "✅ Homebrew is already installed"
fi

echo ""

# Install packages from Brewfile if it exists
if [ -f "$DOTFILES_PATH/brew/Brewfile" ]; then
  echo "📦 Installing development tools and applications from Brewfile..."
  echo "   (This may take several minutes on a fresh install)"
  echo ""
  brew bundle --file="$DOTFILES_PATH/brew/Brewfile"
  echo ""
  echo "⬆️  Upgrading outdated packages..."
  brew upgrade
  echo ""
  echo "✅ All packages from Brewfile are now installed and up to date!"
  echo "   Run 'brew list' to see what's installed"
else
  echo "⚠️  Brewfile not found - skipping package installation"
fi

echo ""
echo "Homebrew setup complete!"