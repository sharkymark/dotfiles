#!/bin/bash

# Parse arguments
DRY_RUN=false
if [[ "$1" == "--dry-run" ]] || [[ "$1" == "-n" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No files will be modified"
    echo ""
fi

echo "RUNNING dotfiles repo install.sh"

# Export DOTFILES_PATH (needed by brew.sh and referenced throughout)
export DOTFILES_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step tracking for the end-of-run summary table.
# Each entry is tab-separated: status<TAB>name<TAB>detail
STEP_RESULTS=()
BREW_CHANGES=""
REPO_CURRENT_CHANGES=""
BACKUP_DELETED_TOTAL=0

record_step() {
    # Usage: record_step <name> <status> [detail]
    local name="$1"
    local status="$2"
    local detail="${3:--}"
    STEP_RESULTS+=("${status}"$'\t'"${name}"$'\t'"${detail}")
}

# Sets COPY_BACKUP=true if target exists before the copy, false otherwise.
# Call BEFORE the cp so we can report whether a backup was made.
detect_backup() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        COPY_BACKUP=true
    else
        COPY_BACKUP=false
    fi
}

copy_detail() {
    if [ "$COPY_BACKUP" = true ]; then
        echo "copied (backup made)"
    else
        echo "copied (first run)"
    fi
}

echo ""
echo "STEP: 🍺 setting up Homebrew packages"
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "$DOTFILES_PATH/brew/brew.sh" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would execute: brew/brew.sh"
            BREW_CHANGES="  (dry-run, not measured)"$'\n'
            record_step "Homebrew packages" "dry-run" "would run brew bundle"
        else
            if command -v brew &> /dev/null; then
                BREW_BEFORE_FORMULA=$(brew list --formula --versions 2>/dev/null | sort)
                BREW_BEFORE_CASK=$(brew list --cask --versions 2>/dev/null | sort)
            else
                BREW_BEFORE_FORMULA=""
                BREW_BEFORE_CASK=""
            fi
            bash "$DOTFILES_PATH/brew/brew.sh"
            BREW_RC=$?
            if command -v brew &> /dev/null; then
                BREW_AFTER_FORMULA=$(brew list --formula --versions 2>/dev/null | sort)
                BREW_AFTER_CASK=$(brew list --cask --versions 2>/dev/null | sort)
                BREW_INSTALLED_COUNT=0
                BREW_UPGRADED_COUNT=0
                BREW_CHANGES=""
                # bash 3.2 safe: no associative arrays. Diff against the sorted
                # `brew list --versions` snapshots taken before/after brew bundle.
                diff_brew_kind() {
                    # $1 = kind label (formula/cask), $2 = before list, $3 = after list
                    local kind="$1"
                    local before="$2"
                    local after="$3"
                    local before_names after_names newly_installed
                    local line name versions before_line before_versions
                    before_names=$(printf '%s\n' "$before" | awk 'NF{print $1}' | sort -u)
                    after_names=$(printf '%s\n'  "$after"  | awk 'NF{print $1}' | sort -u)
                    # New installs: names in after but not in before
                    newly_installed=$(comm -13 <(printf '%s\n' "$before_names") <(printf '%s\n' "$after_names"))
                    if [ -n "$newly_installed" ]; then
                        while IFS= read -r name; do
                            [ -z "$name" ] && continue
                            versions=$(printf '%s\n' "$after" | awk -v n="$name" '$1==n {$1=""; sub(/^ /,""); print; exit}')
                            BREW_CHANGES+="  installed: ${name} ${versions} (${kind})"$'\n'
                            BREW_INSTALLED_COUNT=$((BREW_INSTALLED_COUNT + 1))
                        done <<< "$newly_installed"
                    fi
                    # Upgrades: name in both, version column differs
                    while IFS= read -r line; do
                        [ -z "$line" ] && continue
                        name="${line%% *}"
                        versions="${line#* }"
                        if printf '%s\n' "$before_names" | grep -Fxq -- "$name"; then
                            before_line=$(printf '%s\n' "$before" | awk -v n="$name" '$1==n {print; exit}')
                            before_versions="${before_line#* }"
                            if [ "$before_versions" != "$versions" ]; then
                                BREW_CHANGES+="  upgraded:  ${name} ${before_versions} -> ${versions} (${kind})"$'\n'
                                BREW_UPGRADED_COUNT=$((BREW_UPGRADED_COUNT + 1))
                            fi
                        fi
                    done <<< "$after"
                }
                diff_brew_kind "formula" "$BREW_BEFORE_FORMULA" "$BREW_AFTER_FORMULA"
                diff_brew_kind "cask" "$BREW_BEFORE_CASK" "$BREW_AFTER_CASK"
                BREW_CHANGED_NAMES=$(printf '%s' "$BREW_CHANGES" \
                    | awk '/^  (installed|upgraded)/ {print $2}' \
                    | awk '!seen[$0]++' \
                    | paste -sd, -)
                if [ "$BREW_INSTALLED_COUNT" -eq 0 ] && [ "$BREW_UPGRADED_COUNT" -eq 0 ]; then
                    BREW_DETAIL="no changes"
                elif [ -n "$BREW_CHANGED_NAMES" ]; then
                    BREW_DETAIL="${BREW_UPGRADED_COUNT} upgraded, ${BREW_INSTALLED_COUNT} installed (${BREW_CHANGED_NAMES})"
                else
                    BREW_DETAIL="${BREW_UPGRADED_COUNT} upgraded, ${BREW_INSTALLED_COUNT} installed"
                fi
            else
                BREW_CHANGES="(brew not available after install)"
                BREW_DETAIL="brew unavailable"
            fi
            if [ "$BREW_RC" -eq 0 ]; then
                record_step "Homebrew packages" "done" "$BREW_DETAIL"
            else
                record_step "Homebrew packages" "failed" "brew.sh exit $BREW_RC"
            fi
        fi
    else
        echo "brew.sh not found in brew directory"
        record_step "Homebrew packages" "skipped" "brew.sh not found"
    fi
else
    echo "Skipping Homebrew setup on non-Darwin system"
    record_step "Homebrew packages" "skipped" "non-Darwin system"
fi

echo ""
echo "STEP: 💾 copying .gitignore_global"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./git/.gitignore_global → ~/.gitignore_global"
    record_step ".gitignore_global" "dry-run" "would copy"
else
    detect_backup "$HOME/.gitignore_global"
    cp ./git/.gitignore_global ~
    echo "- copied .gitignore_global to $HOME"
    record_step ".gitignore_global" "done" "$(copy_detail)"
fi

echo ""
echo "STEP: 💾 copying prettier formatting files"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./prettier/.prettierrc → ~/.prettierrc"
    record_step "Prettier config" "dry-run" "would copy"
else
    detect_backup "$HOME/.prettierrc"
    cp ./prettier/.prettierrc ~
    echo "- copied .prettierrc 🎨 to $HOME"
    record_step "Prettier config" "done" "$(copy_detail)"
fi

echo ""
echo "STEP: 🤖 Installing Agent Definitions (AGENTS.md)"
if [ -f "./ai/AGENTS.md" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./ai/AGENTS.md → ~/AGENTS.md"
    record_step "AGENTS.md" "dry-run" "would copy"
  else
    detect_backup "$HOME/AGENTS.md"
    # Backup existing AGENTS.md if it exists
    if [ -f "$HOME/AGENTS.md" ]; then
      cp "$HOME/AGENTS.md" "$HOME/AGENTS.md.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing AGENTS.md"
    fi
    cp "./ai/AGENTS.md" "$HOME/AGENTS.md"
    echo "- copied AGENTS.md to $HOME"
    record_step "AGENTS.md" "done" "$(copy_detail)"
  fi
else
  echo "- AGENTS.md not found in ./ai/"
  record_step "AGENTS.md" "skipped" "./ai/AGENTS.md missing"
fi

echo ""
echo "STEP: copying revenue-AGENTS.md to Google Drive notes"
GDRIVE_NOTES="$HOME/Library/CloudStorage/GoogleDrive-mtm20176@gmail.com/My Drive/notes"
if [ ! -d "$GDRIVE_NOTES" ]; then
  echo "- skipping: Google Drive notes folder not mounted at $GDRIVE_NOTES"
  record_step "revenue-AGENTS.md -> Gdrive" "skipped" "Gdrive not mounted"
elif [ ! -f "./ai/revenue-AGENTS.md" ]; then
  echo "- skipping: ./ai/revenue-AGENTS.md not found"
  record_step "revenue-AGENTS.md -> Gdrive" "skipped" "source missing"
elif [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would copy: ./ai/revenue-AGENTS.md → $GDRIVE_NOTES/AGENTS.md"
  record_step "revenue-AGENTS.md -> Gdrive" "dry-run" "would copy to Gdrive"
else
  detect_backup "$GDRIVE_NOTES/AGENTS.md"
  cp "./ai/revenue-AGENTS.md" "$GDRIVE_NOTES/AGENTS.md"
  echo "- copied revenue-AGENTS.md to $GDRIVE_NOTES/AGENTS.md"
  record_step "revenue-AGENTS.md -> Gdrive" "done" "$(copy_detail)"
fi

echo ""
echo "STEP: 🔗 Symlinking AI configurations"
if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would create symlinks for AI configurations"
  record_step "AI config symlinks" "dry-run" "CLAUDE.md, GEMINI.md"
else
  SYMLINK_REPLACED=0
  # Ensure ~/.claude directory exists
  mkdir -p "$HOME/.claude"
  # Remove existing CLAUDE.md if it's a file, to replace with symlink
  if [ -f "$HOME/.claude/CLAUDE.md" ]; then
    rm "$HOME/.claude/CLAUDE.md"
    SYMLINK_REPLACED=$((SYMLINK_REPLACED + 1))
    echo "- removed old ~/.claude/CLAUDE.md file"
  fi
  # Create symlink for CLAUDE.md
  ln -sf "$HOME/AGENTS.md" "$HOME/.claude/CLAUDE.md"
  echo "- symlinked ~/.claude/CLAUDE.md to ~/AGENTS.md"

  # Ensure ~/.gemini directory exists
  mkdir -p "$HOME/.gemini"
  # Remove existing GEMINI.md if it's a file, to replace with symlink (assuming it might exist from previous manual setup)
  if [ -f "$HOME/.gemini/GEMINI.md" ]; then
    rm "$HOME/.gemini/GEMINI.md"
    SYMLINK_REPLACED=$((SYMLINK_REPLACED + 1))
    echo "- removed old ~/.gemini/GEMINI.md file"
  fi
  # Create symlink for GEMINI.md
  ln -sf "$HOME/AGENTS.md" "$HOME/.gemini/GEMINI.md"
  echo "- symlinked ~/.gemini/GEMINI.md to ~/AGENTS.md"
  record_step "AI config symlinks" "done" "CLAUDE.md, GEMINI.md (${SYMLINK_REPLACED} replaced)"
fi

echo ""
echo "STEP: 🤖 copying Claude Code configuration files"
# Ensure ~/.claude directory exists
mkdir -p "$HOME/.claude"

# Copy settings.json
if [ -f "./.claude/settings.json" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./.claude/settings.json → ~/.claude/settings.json"
    record_step "Claude Code settings.json" "dry-run" "would copy"
  else
    detect_backup "$HOME/.claude/settings.json"
    # Backup existing settings.json if it exists
    if [ -f "$HOME/.claude/settings.json" ]; then
      cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing settings.json"
    fi
    cp ./.claude/settings.json "$HOME/.claude/settings.json"
    echo "- copied settings.json to ~/.claude/"
    echo "- NOTE: You'll need to restart Claude Code for settings to take effect"
    record_step "Claude Code settings.json" "done" "$(copy_detail)"
  fi
else
  echo "- settings.json not found in ./.claude/"
  record_step "Claude Code settings.json" "skipped" "source missing"
fi

echo ""
echo "STEP: 🤖 copying Gemini configuration files"
# Ensure ~/.gemini directory exists
mkdir -p "$HOME/.gemini"

# Copy settings.json
if [ -f "./ai/gemini_settings.json" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./ai/gemini_settings.json → ~/.gemini/settings.json"
    record_step "Gemini settings.json" "dry-run" "would copy"
  else
    detect_backup "$HOME/.gemini/settings.json"
    # Backup existing settings.json if it exists
    if [ -f "$HOME/.gemini/settings.json" ]; then
      cp "$HOME/.gemini/settings.json" "$HOME/.gemini/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing settings.json"
    fi
    cp "./ai/gemini_settings.json" "$HOME/.gemini/settings.json"
    echo "- copied gemini_settings.json to ~/.gemini/"
    record_step "Gemini settings.json" "done" "$(copy_detail)"
  fi
else
  echo "- gemini_settings.json not found in ./ai/"
  record_step "Gemini settings.json" "skipped" "source missing"
fi

echo ""
echo "STEP: 💾 copying shell configuration files e.g., bash, fish, zsh"
echo "🐚 shell is $SHELL"
SHELL_COPIED=()
SHELL_DRY_RUN_USED=false

# Check for bash
if [ "$SHELL" == "/bin/bash" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./shell/bash/.bashrc → ~/.bashrc"
    echo "[DRY RUN] Would copy: ./shell/bash/.bash_profile → ~/.bash_profile"
    SHELL_DRY_RUN_USED=true
  else
    BASH_HAD_BACKUP=false
    if [ -f "$HOME/.bashrc" ]; then
      cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing .bashrc"
      BASH_HAD_BACKUP=true
    fi
    if [ -f "$HOME/.bash_profile" ]; then
      cp "$HOME/.bash_profile" "$HOME/.bash_profile.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing .bash_profile"
      BASH_HAD_BACKUP=true
    fi
    cp ./shell/bash/.bashrc $HOME/.bashrc
    cp ./shell/bash/.bash_profile $HOME/.bash_profile
    echo "- copied bash 👾 configuration files to $HOME"
    if [ "$BASH_HAD_BACKUP" = true ]; then SHELL_COPIED+=("bash (backup)"); else SHELL_COPIED+=("bash (first run)"); fi
  fi
fi

# Check for zsh
if [ "$SHELL" == "/bin/zsh" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./shell/zsh/.zshrc → ~/.zshrc"
    SHELL_DRY_RUN_USED=true
  else
    ZSH_HAD_BACKUP=false
    if [ -f "$HOME/.zshrc" ]; then
      cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing .zshrc"
      ZSH_HAD_BACKUP=true
    fi
    cp ./shell/zsh/.zshrc $HOME/.zshrc
    echo "- copied zsh 🍎 configuration files to $HOME"
    if [ "$ZSH_HAD_BACKUP" = true ]; then SHELL_COPIED+=("zsh (backup)"); else SHELL_COPIED+=("zsh (first run)"); fi
  fi
fi

# Check for fish (regardless of current shell)
if command -v fish &> /dev/null; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./shell/fish/config.fish → ~/.config/fish/config.fish"
    SHELL_DRY_RUN_USED=true
  else
    FISH_HAD_BACKUP=false
    if [ -f "$HOME/.config/fish/config.fish" ]; then
      cp "$HOME/.config/fish/config.fish" "$HOME/.config/fish/config.fish.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing config.fish"
      FISH_HAD_BACKUP=true
    fi
    cp ./shell/fish/config.fish $HOME/.config/fish/config.fish
    echo "- copied fish 🐟 configuration files to $HOME/.config/fish"
    if [ "$FISH_HAD_BACKUP" = true ]; then SHELL_COPIED+=("fish (backup)"); else SHELL_COPIED+=("fish (first run)"); fi
  fi
fi

# If none of the above conditions are met, print a message
if [ "$SHELL" != "/bin/bash" ] && [ "$SHELL" != "/bin/zsh" ] && ! command -v fish &> /dev/null; then
  echo "- no unix shell dotfiles copied. Please ensure you have bash, zsh, or fish installed."
fi

if [ "$DRY_RUN" = true ] && [ "$SHELL_DRY_RUN_USED" = true ]; then
  record_step "Shell configs" "dry-run" "would copy shell rc files"
elif [ "${#SHELL_COPIED[@]}" -gt 0 ]; then
  record_step "Shell configs" "done" "$(IFS=, ; echo "${SHELL_COPIED[*]}")"
else
  record_step "Shell configs" "skipped" "no supported shell"
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

copy_ghostty_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_source="$dotfiles_dir/ghostty/config"
    local ghostty_config_dir="$HOME/.config/ghostty"
    local config_target="$ghostty_config_dir/config"

    mkdir -p "$ghostty_config_dir"
    COPY_BACKUP=false

    if [ -f "$config_source" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would copy: $config_source → $config_target"
        else
            if [ -f "$config_target" ]; then
                cp "$config_target" "$config_target.backup.$(date +%Y%m%d_%H%M%S)"
                echo "- backed up existing ghostty config"
                COPY_BACKUP=true
            fi
            if cp "$config_source" "$config_target"; then
                echo "- copied Ghostty config to $config_target"
            else
                echo "- failed to copy Ghostty config to $config_target"
            fi
        fi
    else
        echo "- ghostty/config not found in $dotfiles_dir/ghostty"
    fi
}

copy_starship_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_source="$dotfiles_dir/starship/starship.toml"
    local config_target="$HOME/.config/starship.toml"

    mkdir -p "$HOME/.config"
    COPY_BACKUP=false

    if [ -f "$config_source" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would copy: $config_source → $config_target"
        else
            if [ -f "$config_target" ]; then
                cp "$config_target" "$config_target.backup.$(date +%Y%m%d_%H%M%S)"
                echo "- backed up existing starship config"
                COPY_BACKUP=true
            fi
            if cp "$config_source" "$config_target"; then
                echo "- copied Starship config to $config_target"
            else
                echo "- failed to copy Starship config to $config_target"
            fi
        fi
    else
        echo "- starship/starship.toml not found in $dotfiles_dir/starship"
    fi
}

copy_atuin_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_source="$dotfiles_dir/atuin/config.toml"
    local atuin_config_dir="$HOME/.config/atuin"
    local config_target="$atuin_config_dir/config.toml"

    mkdir -p "$atuin_config_dir"
    COPY_BACKUP=false

    if [ -f "$config_source" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would copy: $config_source → $config_target"
        else
            if [ -f "$config_target" ]; then
                cp "$config_target" "$config_target.backup.$(date +%Y%m%d_%H%M%S)"
                echo "- backed up existing atuin config"
                COPY_BACKUP=true
            fi
            if cp "$config_source" "$config_target"; then
                echo "- copied Atuin config to $config_target"
            else
                echo "- failed to copy Atuin config to $config_target"
            fi
        fi
    else
        echo "- atuin/config.toml not found in $dotfiles_dir/atuin"
    fi
}

copy_nvim_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local nvim_config_dir="$HOME/.config/nvim"
    local nvim_files=("init.lua" "lazy-lock.json" ".avante_pref")

    mkdir -p "$nvim_config_dir"
    NVIM_FILES_COPIED=0
    NVIM_BACKUPS=0

    for file in "${nvim_files[@]}"; do
        local source="$dotfiles_dir/nvim/$file"
        local target="$nvim_config_dir/$file"

        if [ -f "$source" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "[DRY RUN] Would copy: $source → $target"
            else
                if [ -f "$target" ]; then
                    cp "$target" "$target.backup.$(date +%Y%m%d_%H%M%S)"
                    echo "- backed up existing $file"
                    NVIM_BACKUPS=$((NVIM_BACKUPS + 1))
                fi
                if cp "$source" "$target"; then
                    echo "- copied $file to $nvim_config_dir/"
                    NVIM_FILES_COPIED=$((NVIM_FILES_COPIED + 1))
                else
                    echo "- failed to copy $file to $nvim_config_dir/"
                fi
            fi
        else
            echo "- nvim/$file not found in $dotfiles_dir/nvim"
        fi
    done
}

# Function to clean up old backups, keeping only the two most recent
cleanup_backups() {
    local target_dir="$1"
    local base_filename="$2"
    local backup_files=()

    # Find all backup files for the given base_filename, sorted by name (chronological)
    while IFS= read -r -d $'\0' file; do
        backup_files+=("$file")
    done < <(find "$target_dir" -maxdepth 1 -type f -name "${base_filename}.backup.*" -print0 | sort -z)

    local num_backups=${#backup_files[@]}

    if (( num_backups > 2 )); then
        echo "- Found $num_backups backups for $base_filename in "$target_dir". Keeping the 2 newest."
        # Delete backups from the 3rd oldest onwards
        for (( i=0; i < num_backups - 2; i++ )); do
            if [ "$DRY_RUN" = true ]; then
                echo "[DRY RUN] Would delete old backup: ${backup_files[i]}"
            else
                rm "${backup_files[i]}"
                echo "  Deleted: ${backup_files[i]}"
                BACKUP_DELETED_TOTAL=$((BACKUP_DELETED_TOTAL + 1))
            fi
        done
    fi
}

echo ""
echo "STEP: 💾 copying VS Code IDE configs"
if check_vscode_installed; then
    copy_vscode_settings
    if [ "$DRY_RUN" = true ]; then
        record_step "VS Code configs" "dry-run" "would copy settings.json, extensions.json"
    else
        record_step "VS Code configs" "done" "settings.json, extensions.json"
    fi
else
    echo "Installation of VS Code settings.json skipped due to VS Code not being installed."
    record_step "VS Code configs" "skipped" "VS Code not installed"
fi

echo ""
echo "STEP: 💾 copying Zed IDE configs"
if command -v zed &> /dev/null; then
    copy_zed_settings
    if [ "$DRY_RUN" = true ]; then
        record_step "Zed configs" "dry-run" "would copy settings.json, keymap.json"
    else
        record_step "Zed configs" "done" "settings.json, keymap.json"
    fi
else
    echo "Zed is not installed. Installation of Zed settings.json skipped."
    record_step "Zed configs" "skipped" "Zed not installed"
fi

echo ""
echo "STEP: 👻 copying Ghostty terminal config"
if brew list --cask ghostty &> /dev/null 2>&1; then
    copy_ghostty_settings
    if [ "$DRY_RUN" = true ]; then
        record_step "Ghostty config" "dry-run" "would copy"
    else
        record_step "Ghostty config" "done" "$(copy_detail)"
    fi
else
    echo "Ghostty is not installed. Skipping ghostty config."
    record_step "Ghostty config" "skipped" "Ghostty not installed"
fi

echo ""
echo "STEP: 🚀 copying Starship prompt config"
if command -v starship &> /dev/null; then
    copy_starship_settings
    if [ "$DRY_RUN" = true ]; then
        record_step "Starship config" "dry-run" "would copy"
    else
        record_step "Starship config" "done" "$(copy_detail)"
    fi
else
    echo "Starship is not installed. Skipping starship config."
    record_step "Starship config" "skipped" "Starship not installed"
fi

echo ""
echo "STEP: copying Atuin config"
if command -v atuin &> /dev/null; then
    copy_atuin_settings
    if [ "$DRY_RUN" = true ]; then
        record_step "Atuin config" "dry-run" "would copy"
    else
        record_step "Atuin config" "done" "$(copy_detail)"
    fi
else
    echo "Atuin is not installed. Skipping atuin config."
    record_step "Atuin config" "skipped" "Atuin not installed"
fi

echo ""
echo "STEP: 💾 copying Neovim config"
if command -v nvim &> /dev/null; then
    copy_nvim_settings
    if [ "$DRY_RUN" = true ]; then
        record_step "Neovim config" "dry-run" "would copy 3 files"
    else
        record_step "Neovim config" "done" "${NVIM_FILES_COPIED} copied, ${NVIM_BACKUPS} backed up"
    fi
else
    echo "Neovim is not installed. Skipping Neovim configuration."
    record_step "Neovim config" "skipped" "Neovim not installed"
fi

echo ""
echo "STEP: 🍎 configuring macOS defaults"
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -f "$DOTFILES_PATH/mac/macos.sh" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would execute: mac/macos.sh"
            record_step "macOS defaults" "dry-run" "would apply system settings"
        else
            MACOS_OUT=$(bash "$DOTFILES_PATH/mac/macos.sh" 2>&1)
            MACOS_RC=$?
            printf '%s\n' "$MACOS_OUT"
            if [ "$MACOS_RC" -eq 0 ]; then
                MACOS_APPLIED=$(printf '%s\n' "$MACOS_OUT" | grep -c '^✅')
                MACOS_NAMES=$(printf '%s\n' "$MACOS_OUT" | grep '^✅' | sed -E 's/^✅ //; s/ *\([^)]*\)$//' | paste -sd, -)
                if [ -n "$MACOS_NAMES" ]; then
                    record_step "macOS defaults" "done" "${MACOS_APPLIED} applied: ${MACOS_NAMES}"
                else
                    record_step "macOS defaults" "done" "${MACOS_APPLIED} applied"
                fi
            else
                record_step "macOS defaults" "failed" "macos.sh exit $MACOS_RC"
            fi
        fi
    else
        echo "macos.sh not found in mac directory"
        record_step "macOS defaults" "skipped" "macos.sh missing"
    fi
else
    echo "Skipping macOS defaults on non-Darwin system"
    record_step "macOS defaults" "skipped" "non-Darwin system"
fi

echo ""
echo "STEP: 🧹 Cleaning up old backups"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would clean up old backup files, keeping only the 2 most recent."
    record_step "Backup cleanup" "dry-run" "would clean old backups"
else
    # Clean up AGENTS.md backups
    cleanup_backups "$HOME" "AGENTS.md"
    # Clean up Claude settings.json backups
    cleanup_backups "$HOME/.claude" "settings.json"
    # Clean up old CLAUDE.md files (that were backed up before it became a symlink)
    cleanup_backups "$HOME/.claude" "CLAUDE.md"
    # Clean up Gemini settings.json backups
    cleanup_backups "$HOME/.gemini" "settings.json"
    # Clean up shell backups
    cleanup_backups "$HOME" ".bashrc"
    cleanup_backups "$HOME" ".bash_profile"
    cleanup_backups "$HOME" ".zshrc"
    cleanup_backups "$HOME/.config/fish" "config.fish"
    # Clean up Atuin config backups
    cleanup_backups "$HOME/.config/atuin" "config.toml"
    # Clean up Ghostty config backups
    cleanup_backups "$HOME/.config/ghostty" "config"
    # Clean up Starship config backups
    cleanup_backups "$HOME/.config" "starship.toml"
    # Clean up Neovim config backups
    cleanup_backups "$HOME/.config/nvim" "init.lua"
    cleanup_backups "$HOME/.config/nvim" "lazy-lock.json"
    cleanup_backups "$HOME/.config/nvim" ".avante_pref"
    if [ "$BACKUP_DELETED_TOTAL" -eq 0 ]; then
        record_step "Backup cleanup" "done" "nothing to clean"
    else
        record_step "Backup cleanup" "done" "${BACKUP_DELETED_TOTAL} old backups deleted"
    fi
fi

echo ""
echo "STEP: 🎭 Installing Playwright browser binaries"
if command -v uv &>/dev/null; then
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would run: uv run --with playwright python3 -m playwright install chromium"
        record_step "Playwright (chromium)" "dry-run" "would install chromium"
    else
        PLAYWRIGHT_OUT=$(uv run --with playwright python3 -m playwright install chromium 2>&1)
        PLAYWRIGHT_RC=$?
        printf '%s\n' "$PLAYWRIGHT_OUT"
        echo "- Playwright chromium binary installed"
        if [ "$PLAYWRIGHT_RC" -eq 0 ]; then
            if printf '%s' "$PLAYWRIGHT_OUT" | grep -q "is already installed"; then
                record_step "Playwright (chromium)" "done" "chromium (already installed)"
            else
                record_step "Playwright (chromium)" "done" "chromium installed"
            fi
        else
            record_step "Playwright (chromium)" "failed" "exit $PLAYWRIGHT_RC"
        fi
    fi
else
    echo "- uv not found, skipping Playwright install (run 'brew bundle' first)"
    record_step "Playwright (chromium)" "skipped" "uv not installed"
fi

echo ""
echo "STEP: 🔄 Keeping sibling repos current (repo-current)"
REPO_CURRENT_DIR="$DOTFILES_PATH/../repo-current"
REPO_CURRENT_SCRIPT="$REPO_CURRENT_DIR/git_pull_all.sh"
REPO_CURRENT_URL="https://github.com/sharkymark/repo-current.git"
REPO_CURRENT_FRESH_CLONE=false
# Hardcoded default scan path. Stored as a literal string with $HOME so
# git_pull_all.sh expands it at read time. Edit directories.txt after the
# first run if your dev tree lives somewhere else on a given Mac.
REPO_CURRENT_PREFERRED_PATH='$HOME/Documents/dev_and_debug/src'

if [ ! -d "$REPO_CURRENT_DIR" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would clone $REPO_CURRENT_URL into $REPO_CURRENT_DIR"
        echo "[DRY RUN] Would set directories.txt to: $REPO_CURRENT_PREFERRED_PATH"
        record_step "repo-current" "dry-run" "would clone"
        REPO_CURRENT_READY=false
    else
        echo "- repo-current not found at $REPO_CURRENT_DIR — cloning from $REPO_CURRENT_URL"
        if git clone "$REPO_CURRENT_URL" "$REPO_CURRENT_DIR"; then
            echo "- cloned repo-current"
            REPO_CURRENT_READY=true
            REPO_CURRENT_FRESH_CLONE=true
        else
            echo "- failed to clone repo-current"
            record_step "repo-current" "failed" "clone failed"
            REPO_CURRENT_READY=false
        fi
    fi
else
    echo "- using existing repo-current at $REPO_CURRENT_DIR (re-using your directories.txt)"
    REPO_CURRENT_READY=true
fi

if [ "$REPO_CURRENT_READY" = true ]; then
    REPO_CURRENT_DIRS_FILE="$REPO_CURRENT_DIR/directories.txt"

    if [ "$REPO_CURRENT_FRESH_CLONE" = true ]; then
        # We just cloned, so directories.txt is the upstream generic default
        # ($HOME/Documents/src) that doesn't fit our layout. Replace it with
        # the actual sibling-repos root on this machine. Safe because we just
        # created the file ourselves — no user customizations to destroy.
        echo "$REPO_CURRENT_PREFERRED_PATH" > "$REPO_CURRENT_DIRS_FILE"
        echo "- initialized $REPO_CURRENT_DIRS_FILE to scan: $REPO_CURRENT_PREFERRED_PATH"
        echo "  (edit that file to add or change directories to scan)"
    elif [ ! -f "$REPO_CURRENT_DIRS_FILE" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY RUN] Would seed $REPO_CURRENT_DIRS_FILE with: $REPO_CURRENT_PREFERRED_PATH"
        else
            echo "$REPO_CURRENT_PREFERRED_PATH" > "$REPO_CURRENT_DIRS_FILE"
            echo "- seeded $REPO_CURRENT_DIRS_FILE with: $REPO_CURRENT_PREFERRED_PATH"
        fi
    fi

    # Validate directories.txt entries against the real filesystem.
    # Do NOT overwrite the file when it pre-existed — those are user customizations.
    REPO_CURRENT_VALID=0
    REPO_CURRENT_INVALID=0
    if [ -f "$REPO_CURRENT_DIRS_FILE" ]; then
        while IFS= read -r raw || [ -n "$raw" ]; do
            case "$raw" in ''|\#*) continue;; esac
            expanded=$(eval echo "$raw")
            if [ -d "$expanded" ]; then
                REPO_CURRENT_VALID=$((REPO_CURRENT_VALID + 1))
            else
                REPO_CURRENT_INVALID=$((REPO_CURRENT_INVALID + 1))
            fi
        done < "$REPO_CURRENT_DIRS_FILE"
    fi

    if [ ! -f "$REPO_CURRENT_SCRIPT" ]; then
        echo "- git_pull_all.sh missing in $REPO_CURRENT_DIR"
        record_step "repo-current" "failed" "git_pull_all.sh missing"
    elif [ "$REPO_CURRENT_VALID" -eq 0 ] && [ "$DRY_RUN" != true ]; then
        echo "- WARNING: no valid directories found in $REPO_CURRENT_DIRS_FILE"
        echo "  current contents:"
        sed 's/^/    /' "$REPO_CURRENT_DIRS_FILE"
        echo "  none of those paths exist on this machine."
        echo "  To use this machine's standard layout, run:"
        echo "    echo \"$REPO_CURRENT_PREFERRED_PATH\" > \"$REPO_CURRENT_DIRS_FILE\""
        echo "  Then re-run install.sh."
        record_step "repo-current" "skipped" "no valid dirs in directories.txt"
    elif [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would execute: (cd $REPO_CURRENT_DIR && ./git_pull_all.sh --summary-only)"
        record_step "repo-current" "dry-run" "${REPO_CURRENT_VALID} valid dir(s)"
    else
        REPO_CURRENT_OUT=$( ( cd "$REPO_CURRENT_DIR" && bash ./git_pull_all.sh --summary-only ) 2>&1 )
        REPO_CURRENT_RC=$?
        printf '%s\n' "$REPO_CURRENT_OUT"
        REPO_CURRENT_CHANGES=$(printf '%s\n' "$REPO_CURRENT_OUT" \
            | awk '/=== AFFECTED REPOSITORIES ===/,/^Finished processing directories\./' \
            | sed '$d')
        # Parse footer lines emitted by git_pull_all.sh
        RC_PROCESSED=$(printf '%s\n' "$REPO_CURRENT_OUT" | awk -F': ' '/^Total repositories processed:/ {print $2; exit}')
        RC_PULLED=$(printf '%s\n'    "$REPO_CURRENT_OUT" | awk -F': ' '/^Total repositories with actual changes pulled:/ {print $2; exit}')
        RC_UPTODATE=$(printf '%s\n'  "$REPO_CURRENT_OUT" | awk -F': ' '/^Total repositories already up to date:/ {print $2; exit}')
        RC_PROBLEMS=$(printf '%s\n'  "$REPO_CURRENT_OUT" | awk -F': ' '/^Total repositories with problems:/ {print $2; exit}')
        : "${RC_PROCESSED:=?}"; : "${RC_PULLED:=0}"; : "${RC_UPTODATE:=0}"; : "${RC_PROBLEMS:=0}"
        REPO_CURRENT_DETAIL="${RC_PULLED} updated, ${RC_UPTODATE} unchanged, ${RC_PROBLEMS} problems (of ${RC_PROCESSED})"
        if [ "$REPO_CURRENT_RC" -eq 0 ]; then
            record_step "repo-current" "done" "$REPO_CURRENT_DETAIL"
        else
            record_step "repo-current" "failed" "exit $REPO_CURRENT_RC ($REPO_CURRENT_DETAIL)"
        fi
    fi
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

echo "======================================"
echo "📋 Dotfiles run summary"
echo "======================================"
printf '%-10s %-32s %s\n' "STATUS" "STEP" "DETAIL"
printf '%-10s %-32s %s\n' "------" "----" "------"
COUNT_DONE=0
COUNT_SKIPPED=0
COUNT_FAILED=0
COUNT_DRY=0
for entry in "${STEP_RESULTS[@]}"; do
    status="${entry%%$'\t'*}"
    rest="${entry#*$'\t'}"
    name="${rest%%$'\t'*}"
    detail="${rest#*$'\t'}"
    printf '%-10s %-32s %s\n' "$status" "$name" "$detail"
    case "$status" in
        done) COUNT_DONE=$((COUNT_DONE + 1)) ;;
        skipped) COUNT_SKIPPED=$((COUNT_SKIPPED + 1)) ;;
        failed) COUNT_FAILED=$((COUNT_FAILED + 1)) ;;
        dry-run) COUNT_DRY=$((COUNT_DRY + 1)) ;;
    esac
done

echo ""
echo "Brew package changes:"
if [ -z "$BREW_CHANGES" ]; then
    echo "  (no changes)"
else
    # Trim trailing newline if present
    printf '%s' "$BREW_CHANGES"
fi

echo ""
echo "Repo-current changes:"
if [ -z "$REPO_CURRENT_CHANGES" ]; then
    echo "  (not run, or no affected repos)"
else
    printf '%s\n' "$REPO_CURRENT_CHANGES"
fi

echo ""
echo "Totals: ${COUNT_DONE} done, ${COUNT_SKIPPED} skipped, ${COUNT_FAILED} failed, ${COUNT_DRY} dry-run"
echo ""
