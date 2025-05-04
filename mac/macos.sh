#!/bin/bash

echo "Setting macOS defaults..."

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
killall Finder 2> /dev/null # Ignore error if Finder isn't running

# Mouse tracking speed that I like
defaults write -g com.apple.mouse.scaling -float 2.5 

echo "macOS defaults applied."