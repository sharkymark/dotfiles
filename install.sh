#!/bin/bash

echo "RUNNING dotfiles repo install.sh"

echo ""
echo "STEP 1: 💾 copying .gitconfig and .gitignore_global"
cp -r ./git/.gitconfig ./git/.gitignore_global ~

echo ""
echo "STEP 2: 💾 copying prettier formatting files"
cp ./prettier/.prettierrc ~
echo "- copied .prettierrc 🎨 to $HOME"

echo ""
echo "STEP 3: 💾 copying shell configuration files e.g., bash, fish, zsh"
echo "🐚 shell is $SHELL"

# Check for bash
if [ "$SHELL" == "/bin/bash" ]; then
  cp ./shell/bash/.bashrc $HOME/.bashrc
  cp ./shell/bash/.bash_profile $HOME/.bash_profile
  echo "- copied bash 👾 configuration files to $HOME"
fi

# Check for zsh
if [ "$SHELL" == "/bin/zsh" ]; then
  cp ./shell/zsh/.zshrc $HOME/.zshrc
  echo "- copied zsh 🍎 configuration files to $HOME"
fi

# Check for fish (regardless of current shell)
if command -v fish &> /dev/null; then
  cp ./shell/fish/config.fish $HOME/.config/fish/config.fish
  echo "- copied fish 🐟 configuration files to $HOME/.config/fish"
fi

# If none of the above conditions are met, print a message
if [ "$SHELL" != "/bin/bash" ] && [ "$SHELL" != "/bin/zsh" ] && ! command -v fish &> /dev/null; then
  echo "- no unix shell dotfiles copied. Please ensure you have bash, zsh, or fish installed."
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
    local dotfiles_dir="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    local settings_source="$dotfiles_dir/code/settings.json"
    local extensions_source="$dotfiles_dir/code/extensions.json"
    local vscode_dir="$HOME/.vscode"
    local settings_target="$HOME/Library/Application Support/Code/User/settings.json"

    # Check if VS Code settings directory exists (handle spaces in path)
    if [ ! -d "$HOME/Library/Application Support/Code/User" ]; then
        echo "- VS Code settings directory not found. Please ensure Visual Studio Code is installed."
        return 1
    fi

    # Copy the settings.json file
    if [ -f "$settings_source" ]; then
        if cp "$settings_source" "$settings_target"; then
            echo "- copied VS Code settings.json to $settings_target"
        else
            echo "- failed to copy VS Code settings.json to $settings_target"
            return 1
        fi
    else
        echo "VS Code settings.json not found in $dotfiles_dir/code"
    fi

    # Check if VS Code extensions directory exists
    if [ ! -d "$vscode_dir" ]; then
        echo "- $vscode_dir not found. Please ensure Visual Studio Code is installed."
        return 1
    fi

    # Copy the extensions.json file
    if [ -f "$extensions_source" ]; then
        if cp "$extensions_source" "$vscode_dir/extensions.json"; then
            echo "- copied VS Code extensions.json to $vscode_dir/extensions.json"
        else
            echo "- failed to copy VS Code extensions.json to $vscode_dir/extensions.json"
            return 1
        fi
    else
        echo "- VS Code extensions.json not found in $dotfiles_dir/code"
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
            echo "- copied Zed settings.json to $zed_config_dir/settings.json"
        else
            echo "- failed to copy Zed settings.json to $zed_config_dir/settings.json"
        fi
    else
        echo "- Zed settings.json not found in $dotfiles_dir/zed"
    fi

    # Copy keymap.json
    if [ -f "$keymap_source" ]; then
        if cp "$keymap_source" "$zed_config_dir/keymap.json"; then
            echo "- copied Zed keymap.json to $zed_config_dir/keymap.json"
        else
            echo "- failed to copy Zed keymap.json to $zed_config_dir/keymap.json"
        fi
    else
        echo "- Zed keymap.json not found in $dotfiles_dir/zed"
    fi
}

# Function to copy Aider configuration
copy_aider_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local aider_config_source="$dotfiles_dir/ai-agents/.original-aider.conf.yml"
    local aider_config_target="$HOME/.aider.conf.yml"

    if [ -f "$aider_config_source" ]; then
        if cp "$aider_config_source" "$aider_config_target"; then
            echo "- copied Aider config 🤖 to $aider_config_target"
        else
            echo "- failed to copy Aider config to $aider_config_target"
        fi
    else
        echo "- Aider config file not found in $dotfiles_dir/aider"
    fi
}

# Function to copy Block Goose configuration
copy_goose_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local goose_config_source="$dotfiles_dir/ai-agents/.original-goose-config.yaml"
    local goose_config_target_dir="$HOME/.config/goose"
    local goose_config_target_file="$goose_config_target_dir/config.yaml"

    if [ -d "$goose_config_target_dir" ]; then
        if [ -f "$goose_config_source" ]; then
            if cp "$goose_config_source" "$goose_config_target_file"; then
                echo "- copied Block Goose config 🤖 to $goose_config_target_file"
            else
                echo "- failed to copy Block Goose config to $goose_config_target_file"
            fi
        else
            echo "- Block Goose config file not found in $dotfiles_dir/ai-agents"
        fi
    else
        echo "- Block Goose config directory $goose_config_target_dir not found. Please install Goose first."
    fi
}

# Function to copy OpenAI Codex CLI configuration
copy_codex_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local codex_config_source_dir="$dotfiles_dir/ai-agents/codex"
    local codex_agents_source_file="$codex_config_source_dir/AGENTS.md"
    local codex_config_source_file="$codex_config_source_dir/config.json"
    local codex_config_target_dir="$HOME/.codex"

    if [ ! -d "$codex_config_target_dir" ]; then
        echo "- OpenAI Codex CLI config directory $codex_config_target_dir not found. Please install OpenAI Codex CLI first."
        return 1
    fi

    local agents_copied=false
    local config_copied=false

    # Copy AGENTS.md
    if [ -f "$codex_agents_source_file" ]; then
        if cp "$codex_agents_source_file" "$codex_config_target_dir/AGENTS.md"; then
            agents_copied=true
        fi
    fi

    # Copy config.json
    if [ -f "$codex_config_source_file" ]; then
        if cp "$codex_config_source_file" "$codex_config_target_dir/config.json"; then
            config_copied=true
        fi
    fi

    if [ "$agents_copied" = true ] && [ "$config_copied" = true ]; then
        echo "- copied OpenAI Codex CLI config (AGENTS.md and config.json) 🤖 to $codex_config_target_dir"
    elif [ "$agents_copied" = true ]; then
        echo "- copied OpenAI Codex AGENTS.md 🤖 to $codex_config_target_dir, but config.json was not found or failed to copy."
    elif [ "$config_copied" = true ]; then
        echo "- copied OpenAI Codex config.json 🤖 to $codex_config_target_dir, but AGENTS.md was not found or failed to copy."
    else
        echo "- failed to copy OpenAI Codex CLI config. Check if AGENTS.md and config.json exist in $codex_config_source_dir."
    fi
}

# Main execution
echo ""
echo "STEP 4: 💾 copying VS Code IDE configs"
if check_vscode_installed; then
    copy_vscode_settings
else
    echo "Installation of VS Code settings.json skipped due to VS Code not being installed."
fi

# Check if Zed is installed
echo ""
echo "STEP 5: 💾 copying Zed IDE configs"
if command -v zed &> /dev/null; then
    copy_zed_settings
else
    echo "Zed is not installed. Installation of Zed settings.json skipped."
fi

echo ""
echo "STEP 6: 🤖 copying Aider config"
copy_aider_settings

echo ""
echo "STEP 7: 🤖 copying Block Goose config"
copy_goose_settings

echo ""
echo "STEP 8: 🤖 copying OpenAI Codex CLI config"
copy_codex_settings

# Export DOTFILES_PATH for brew.sh
export DOTFILES_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Only run macOS specific configurations if on Darwin
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "STEP 9: 🍎 configuring macOS defaults"
    if [ -f "$DOTFILES_PATH/mac/macos.sh" ]; then
        bash "$DOTFILES_PATH/mac/macos.sh"
    else
        echo "macos.sh not found in mac directory"
    fi

    echo ""
    echo "STEP 10: 🍺 setting up Homebrew packages"
    if [ -f "$DOTFILES_PATH/brew/brew.sh" ]; then
        bash "$DOTFILES_PATH/brew/brew.sh"
    else
        echo "brew.sh not found in brew directory"
    fi
else
    echo ""
    echo "Skipping macOS-specific configurations (Homebrew and system defaults) on non-Darwin system"
fi