#!/bin/bash

echo "Configuring macOS system settings..."
echo ""

# Show hidden files in Finder
echo "✅ Enabled hidden files in Finder (dotfiles, system files now visible)"
defaults write com.apple.finder AppleShowAllFiles -bool true
killall Finder 2> /dev/null # Ignore error if Finder isn't running

# Mouse tracking speed that I like
echo "✅ Set mouse tracking speed to 2.5 (faster cursor movement)"
defaults write -g com.apple.mouse.scaling -float 2.5

echo ""
echo "macOS system settings applied successfully!"