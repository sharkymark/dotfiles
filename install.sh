#!/bin/bash

# Parse arguments
DRY_RUN=false
if [[ "$1" == "--dry-run" ]] || [[ "$1" == "-n" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No files will be modified"
    echo ""
fi

echo "RUNNING dotfiles repo install.sh"

echo ""
echo "STEP 1: 💾 copying .gitignore_global"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./git/.gitignore_global → ~/.gitignore_global"
else
    cp ./git/.gitignore_global ~
    echo "- copied .gitignore_global to $HOME"
fi

echo ""
echo "STEP 2: 💾 copying prettier formatting files"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./prettier/.prettierrc → ~/.prettierrc"
else
    cp ./prettier/.prettierrc ~
    echo "- copied .prettierrc 🎨 to $HOME"
fi

echo ""
echo "STEP 3: 🤖 copying Claude Code configuration files"
# Ensure ~/.claude directory exists
mkdir -p "$HOME/.claude"

# Copy CLAUDE.md
if [ -f "./.claude/CLAUDE.md" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./.claude/CLAUDE.md → ~/.claude/CLAUDE.md"
  else
    # Backup existing CLAUDE.md if it exists
    if [ -f "$HOME/.claude/CLAUDE.md" ]; then
      cp "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing CLAUDE.md"
    fi
    cp ./.claude/CLAUDE.md "$HOME/.claude/CLAUDE.md"
    echo "- copied CLAUDE.md to ~/.claude/"
  fi
else
  echo "- CLAUDE.md not found in ./.claude/"
fi

# Copy settings.local.json
if [ -f "./.claude/settings.local.json" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./.claude/settings.local.json → ~/.claude/settings.local.json"
  else
    # Backup existing settings.local.json if it exists
    if [ -f "$HOME/.claude/settings.local.json" ]; then
      cp "$HOME/.claude/settings.local.json" "$HOME/.claude/settings.local.json.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing settings.local.json"
    fi
    cp ./.claude/settings.local.json "$HOME/.claude/settings.local.json"
    echo "- copied settings.local.json to ~/.claude/"
    echo "- NOTE: You'll need to restart Claude Code for settings to take effect"
  fi
else
  echo "- settings.local.json not found in ./.claude/"
fi

echo ""
echo "STEP 4: 💾 copying shell configuration files e.g., bash, fish, zsh"
echo "🐚 shell is $SHELL"

# Check for bash
if [ "$SHELL" == "/bin/bash" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./shell/bash/.bashrc → ~/.bashrc"
    echo "[DRY RUN] Would copy: ./shell/bash/.bash_profile → ~/.bash_profile"
  else
    cp ./shell/bash/.bashrc $HOME/.bashrc
    cp ./shell/bash/.bash_profile $HOME/.bash_profile
    echo "- copied bash 👾 configuration files to $HOME"
  fi
fi

# Check for zsh
if [ "$SHELL" == "/bin/zsh" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./shell/zsh/.zshrc → ~/.zshrc"
  else
    cp ./shell/zsh/.zshrc $HOME/.zshrc
    echo "- copied zsh 🍎 configuration files to $HOME"
  fi
fi

# Check for fish (regardless of current shell)
if command -v fish &> /dev/null; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./shell/fish/config.fish → ~/.config/fish/config.fish"
  else
    cp ./shell/fish/config.fish $HOME/.config/fish/config.fish
    echo "- copied fish 🐟 configuration files to $HOME/.config/fish"
  fi
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
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would copy: $settings_source → $settings_target"
        else
            if cp "$settings_source" "$settings_target"; then
                echo "- copied VS Code settings.json to $settings_target"
            else
                echo "- failed to copy VS Code settings.json to $settings_target"
                return 1
            fi
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
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would copy: $extensions_source → $vscode_dir/extensions.json"
        else
            if cp "$extensions_source" "$vscode_dir/extensions.json"; then
                echo "- copied VS Code extensions.json to $vscode_dir/extensions.json"
            else
                echo "- failed to copy VS Code extensions.json to $vscode_dir/extensions.json"
                return 1
            fi
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
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would copy: $settings_source → $zed_config_dir/settings.json"
        else
            if cp "$settings_source" "$zed_config_dir/settings.json"; then
                echo "- copied Zed settings.json to $zed_config_dir/settings.json"
            else
                echo "- failed to copy Zed settings.json to $zed_config_dir/settings.json"
            fi
        fi
    else
        echo "- Zed settings.json not found in $dotfiles_dir/zed"
    fi

    # Copy keymap.json
    if [ -f "$keymap_source" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would copy: $keymap_source → $zed_config_dir/keymap.json"
        else
            if cp "$keymap_source" "$zed_config_dir/keymap.json"; then
                echo "- copied Zed keymap.json to $zed_config_dir/keymap.json"
            else
                echo "- failed to copy Zed keymap.json to $zed_config_dir/keymap.json"
            fi
        fi
    else
        echo "- Zed keymap.json not found in $dotfiles_dir/zed"
    fi
}

# Main execution
echo ""
echo "STEP 5: 💾 copying VS Code IDE configs"
if check_vscode_installed; then
    copy_vscode_settings
else
    echo "Installation of VS Code settings.json skipped due to VS Code not being installed."
fi

# Check if Zed is installed
echo ""
echo "STEP 6: 💾 copying Zed IDE configs"
if command -v zed &> /dev/null; then
    copy_zed_settings
else
    echo "Zed is not installed. Installation of Zed settings.json skipped."
fi

# Export DOTFILES_PATH for brew.sh
export DOTFILES_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Only run macOS specific configurations if on Darwin
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "STEP 7: 🍎 configuring macOS defaults"
    if [ -f "$DOTFILES_PATH/mac/macos.sh" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would execute: mac/macos.sh"
        else
            bash "$DOTFILES_PATH/mac/macos.sh"
        fi
    else
        echo "macos.sh not found in mac directory"
    fi

    echo ""
    echo "STEP 8: 🍺 setting up Homebrew packages"
    if [ -f "$DOTFILES_PATH/brew/brew.sh" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would execute: brew/brew.sh"
        else
            bash "$DOTFILES_PATH/brew/brew.sh"
        fi
    else
        echo "brew.sh not found in brew directory"
    fi
else
    echo ""
    echo "Skipping macOS-specific configurations (Homebrew and system defaults) on non-Darwin system"
fi

echo ""
echo "======================================"
echo "📝 Git User Configuration"
echo "======================================"
echo ""
echo "Your current git user settings:"
echo "  Name:       $(git config --global user.name 2>/dev/null || echo '(not set)')"
echo "  Email:      $(git config --global user.email 2>/dev/null || echo '(not set)')"
echo "  GPG Key:    $(git config --global user.signingkey 2>/dev/null || echo '(not set)')"
echo "  GPG Sign:   $(git config --global commit.gpgsign 2>/dev/null || echo '(not set)')"
echo ""
echo "To configure your git identity (required for commits):"
echo "  git config --global user.name \"Your Name\""
echo "  git config --global user.email \"your@email.com\""
echo ""
echo "Optional - To enable GPG commit signing:"
echo "  1. List your GPG keys:    gpg --list-secret-keys --keyid-format=long"
echo "  2. Set signing key:       git config --global user.signingkey YOUR_KEY_ID"
echo "  3. Enable auto-signing:   git config --global commit.gpgsign true"
echo ""