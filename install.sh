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

# Function to check if VS Code is installed
check_vscode_installed() {
    if command -v code &> /dev/null; then
        return 0
    else
        echo "Visual Studio Code is not installed."
        return 1
    fi
}

# Rename copy_settings to copy_vscode_settings and update echo statements
copy_vscode_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local settings_source="$dotfiles_dir/code/settings.json"
    local settings_target="$HOME/Library/Application Support/Code/User/settings.json"

    # Check if source file exists
    if [ ! -f "$settings_source" ]; then
        echo "VS Code settings.json not found in $dotfiles_dir/code"
        return 1
    fi

    # Copy the settings file
    if cp "$settings_source" "$settings_target"; then
        echo "💾 copied VS Code settings.json to $settings_target"
    else
        echo "Failed to copy VS Code settings.json to $settings_target"
        return 1
    fi
}

# Update copy_zed_settings to handle keymap.json
copy_zed_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local settings_source="$dotfiles_dir/zed/settings.json"
    local keymap_source="$dotfiles_dir/zed/keymap.json"
    local zed_config_dir="$HOME/.config/zed"

    # Ensure the target directory exists
    mkdir -p "$zed_config_dir"

    # Copy settings.json
    if [ -f "$settings_source" ]; then
        if cp "$settings_source" "$zed_config_dir/settings.json"; then
            echo "💾 copied Zed settings.json to $zed_config_dir/settings.json"
        else
            echo "Failed to copy Zed settings.json to $zed_config_dir/settings.json"
        fi
    else
        echo "Zed settings.json not found in $dotfiles_dir/zed"
    fi

    # Copy keymap.json
    if [ -f "$keymap_source" ]; then
        if cp "$keymap_source" "$zed_config_dir/keymap.json"; then
            echo "💾 copied Zed keymap.json to $zed_config_dir/keymap.json"
        else
            echo "Failed to copy Zed keymap.json to $zed_config_dir/keymap.json"
        fi
    else
        echo "Zed keymap.json not found in $dotfiles_dir/zed"
    fi
}

# Main execution
if check_vscode_installed; then
    copy_vscode_settings
else
    echo "Installation of VS Code settings.json skipped due to VS Code not being installed."
fi

# Check if Zed is installed
if command -v zed &> /dev/null; then
    copy_zed_settings
else
    echo "Zed is not installed. Installation of Zed settings.json skipped."
fi