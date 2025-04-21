#!/bin/bash

echo "Setting macOS defaults..."

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
killall Finder 2> /dev/null # Ignore error if Finder isn't running

# Mouse tracking speed that I like
defaults write -g com.apple.mouse.scaling -float 2.5

# Set black background on desktop
defaults write com.apple.desktop BackgroundType -int 1
defaults write com.apple.desktop SolidColor -array 0 0 0

killall Dock 

echo "macOS defaults applied."