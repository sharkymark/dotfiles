#!/bin/bash

# Parse arguments
DRY_RUN=false
SHOW_REPO_PATH=false
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n)
            DRY_RUN=true
            ;;
        --show-repo-path)
            SHOW_REPO_PATH=true
            ;;
    esac
done
# Local wall clock: 2026-09-01 11:17:32 AM CDT
now_stamp() {
    date '+%Y-%m-%d %I:%M:%S %p %Z'
}

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN MODE - No files will be modified"
    echo ""
fi

INSTALL_STARTED="$(now_stamp)"
echo "RUNNING dotfiles repo install.sh"
echo "Started: $INSTALL_STARTED"

# Export DOTFILES_PATH (needed by brew.sh and referenced throughout)
export DOTFILES_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step tracking for the end-of-run summary table.
# Each entry is tab-separated: status<TAB>name<TAB>detail
STEP_RESULTS=()
BREW_CHANGES=""
REPO_CURRENT_CHANGES=""
TOOL_UPDATES_CHANGES=""
BACKUP_DELETED_TOTAL=0

record_step() {
    # Usage: record_step <name> <status> [detail]
    local name="$1"
    local status="$2"
    local detail="${3:--}"
    STEP_RESULTS+=("${status}"$'\t'"${name}"$'\t'"${detail}")
}

# TTY progress bar: [=====>----] 3/11 label
# Non-TTY: one plain line per tick (no \r redraws).
progress_bar() {
    local current="$1"
    local total="$2"
    local label="${3:-}"
    local width=20
    local filled empty bar empty_bar
    if [ "$total" -le 0 ]; then
        total=1
    fi
    if [ "$current" -gt "$total" ]; then
        current="$total"
    fi
    filled=$(( current * width / total ))
    empty=$(( width - filled ))
    if [ "$filled" -gt 0 ]; then
        bar=$(printf '%*s' "$filled" '' | tr ' ' '=')
        if [ "$filled" -lt "$width" ]; then
            bar="${bar%?}>"
        fi
    else
        bar=""
    fi
    empty_bar=$(printf '%*s' "$empty" '' | tr ' ' '-')
    if [ -t 1 ]; then
        printf '\r[%s%s] %s/%s %s' "$bar" "$empty_bar" "$current" "$total" "$label"
        if [ "$current" -ge "$total" ]; then
            printf '\n'
        fi
    else
        printf '[%s%s] %s/%s %s\n' "$bar" "$empty_bar" "$current" "$total" "$label"
    fi
}

# Clear an in-progress TTY progress line before printing a normal status line.
progress_clear_line() {
    if [ -t 1 ]; then
        printf '\r\033[K'
    fi
}

append_tool_change() {
    # Usage: append_tool_change <line>
    TOOL_UPDATES_CHANGES+="  $1"$'\n'
}

# Record a version change in the summary and print it live.
# Usage: report_upgrade <name> <before> <after>
report_upgrade() {
    local name="$1"
    local before="$2"
    local after="$3"
    progress_clear_line
    echo "  upgraded: $name  $before -> $after"
    append_tool_change "upgraded: $name $before -> $after"
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

print_step() {
    echo ""
    echo "STEP: [$(now_stamp)] $*"
}

print_step "🍺 setting up Homebrew packages"
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

print_step "💾 copying .gitignore_global"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./git/.gitignore_global → ~/.gitignore_global"
    record_step ".gitignore_global" "dry-run" "would copy"
else
    detect_backup "$HOME/.gitignore_global"
    cp ./git/.gitignore_global ~
    echo "- copied .gitignore_global to $HOME"
    record_step ".gitignore_global" "done" "$(copy_detail)"
fi

print_step "💾 copying prettier formatting files"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./prettier/.prettierrc → ~/.prettierrc"
    record_step "Prettier config" "dry-run" "would copy"
else
    detect_backup "$HOME/.prettierrc"
    cp ./prettier/.prettierrc ~
    echo "- copied .prettierrc 🎨 to $HOME"
    record_step "Prettier config" "done" "$(copy_detail)"
fi

print_step "🤖 Installing Agent Definitions (AGENTS.md)"
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

print_step "copying revenue-AGENTS.md to Google Drive notes"
GDRIVE_NOTES="$HOME/Library/CloudStorage/GoogleDrive-mtm20176@gmail.com/My Drive/Notes"
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

print_step "copying Claude Code .mcp.json to Google Drive notes"
if [ ! -d "$GDRIVE_NOTES" ]; then
  echo "- skipping: Google Drive notes folder not mounted at $GDRIVE_NOTES"
  record_step "Claude .mcp.json -> Gdrive" "skipped" "Gdrive not mounted"
elif [ ! -f "./.claude/mcp.json" ]; then
  echo "- skipping: ./.claude/mcp.json not found"
  record_step "Claude .mcp.json -> Gdrive" "skipped" "source missing"
elif [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would copy: ./.claude/mcp.json → $GDRIVE_NOTES/.mcp.json"
  echo "[DRY RUN] Would copy: ./.claude/mcp.json → $GDRIVE_NOTES/4-nuon/.mcp.json"
  record_step "Claude .mcp.json -> Gdrive" "dry-run" "would copy to Notes and 4-nuon"
else
  detect_backup "$GDRIVE_NOTES/.mcp.json"
  cp "./.claude/mcp.json" "$GDRIVE_NOTES/.mcp.json"
  echo "- copied .claude/mcp.json to $GDRIVE_NOTES/.mcp.json"
  mkdir -p "$GDRIVE_NOTES/4-nuon"
  cp "./.claude/mcp.json" "$GDRIVE_NOTES/4-nuon/.mcp.json"
  echo "- copied .claude/mcp.json to $GDRIVE_NOTES/4-nuon/.mcp.json"
  record_step "Claude .mcp.json -> Gdrive" "done" "Notes/.mcp.json, 4-nuon/.mcp.json"
fi

print_step "🔗 Symlinking AI configurations"
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

print_step "🤖 copying Claude Code configuration files"
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

# Copy Claude Code MCP servers (project .mcp.json format) into ~/.claude and
# merge into ~/.claude.json user-scope mcpServers.
if [ -f "./.claude/mcp.json" ]; then
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would copy: ./.claude/mcp.json → ~/.claude/mcp.json"
    echo "[DRY RUN] Would merge mcpServers into ~/.claude.json"
    record_step "Claude Code mcp.json" "dry-run" "would copy + merge user mcpServers"
  else
    detect_backup "$HOME/.claude/mcp.json"
    if [ -f "$HOME/.claude/mcp.json" ]; then
      cp "$HOME/.claude/mcp.json" "$HOME/.claude/mcp.json.backup.$(date +%Y%m%d_%H%M%S)"
      echo "- backed up existing ~/.claude/mcp.json"
    fi
    cp ./.claude/mcp.json "$HOME/.claude/mcp.json"
    echo "- copied mcp.json to ~/.claude/"
    python3 - "$HOME/.claude.json" "./.claude/mcp.json" <<'PY'
import json, sys
claude_json, mcp_json = sys.argv[1], sys.argv[2]
with open(mcp_json) as f:
    mcp = json.load(f)
servers = mcp.get("mcpServers") or {}
try:
    with open(claude_json) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
cfg["mcpServers"] = servers
with open(claude_json, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
    echo "- merged mcpServers into ~/.claude.json (user scope)"
    record_step "Claude Code mcp.json" "done" "$(copy_detail)"
  fi
else
  echo "- mcp.json not found in ./.claude/"
  record_step "Claude Code mcp.json" "skipped" "source missing"
fi

print_step "🤖 copying Gemini configuration files"
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

print_step "💾 copying shell configuration files e.g., bash, fish, zsh"
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
    GHOSTTY_CURSOR_MARKER="# dotfiles: ghostty block cursor"
    GHOSTTY_CURSOR_SOURCE="[[ -f \"$DOTFILES_PATH/shell/zsh/ghostty-cursor.zsh\" ]] && source \"$DOTFILES_PATH/shell/zsh/ghostty-cursor.zsh\""
    if [ -f "$HOME/.zshenv" ] && ! grep -qF "$GHOSTTY_CURSOR_MARKER" "$HOME/.zshenv"; then
      tmp_zshenv="$(mktemp)"
      {
        echo "$GHOSTTY_CURSOR_MARKER"
        echo "$GHOSTTY_CURSOR_SOURCE"
        echo ""
        cat "$HOME/.zshenv"
      } > "$tmp_zshenv"
      cp "$tmp_zshenv" "$HOME/.zshenv"
      rm -f "$tmp_zshenv"
      echo "- wired ghostty block cursor into ~/.zshenv"
    fi
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

copy_goose_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local goose_config_dir="$HOME/.config/goose"
    local goose_files=("config.yaml" "permission.yaml" ".gooseignore")

    mkdir -p "$goose_config_dir"
    GOOSE_FILES_COPIED=0
    GOOSE_BACKUPS=0

    for file in "${goose_files[@]}"; do
        local source="$dotfiles_dir/goose/$file"
        local target="$goose_config_dir/$file"

        if [ -f "$source" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "[DRY RUN] Would copy: $source → $target"
            else
                if [ -f "$target" ]; then
                    cp "$target" "$target.backup.$(date +%Y%m%d_%H%M%S)"
                    echo "- backed up existing $file"
                    GOOSE_BACKUPS=$((GOOSE_BACKUPS + 1))
                fi
                if cp "$source" "$target"; then
                    echo "- copied $file to $goose_config_dir/"
                    GOOSE_FILES_COPIED=$((GOOSE_FILES_COPIED + 1))
                else
                    echo "- failed to copy $file to $goose_config_dir/"
                fi
            fi
        else
            echo "- goose/$file not found in $dotfiles_dir/goose"
        fi
    done
}

copy_cursor_settings() {
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local cursor_config_dir="$HOME/.cursor"
    local cursor_files=("cli-config.json" "mcp.json")

    mkdir -p "$cursor_config_dir"
    CURSOR_FILES_COPIED=0
    CURSOR_BACKUPS=0

    for file in "${cursor_files[@]}"; do
        local source="$dotfiles_dir/cursor/$file"
        local target="$cursor_config_dir/$file"

        if [ -f "$source" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "[DRY RUN] Would copy: $source → $target"
            else
                if [ -f "$target" ]; then
                    cp "$target" "$target.backup.$(date +%Y%m%d_%H%M%S)"
                    echo "- backed up existing $file"
                    CURSOR_BACKUPS=$((CURSOR_BACKUPS + 1))
                fi
                if cp "$source" "$target"; then
                    echo "- copied $file to $cursor_config_dir/"
                    CURSOR_FILES_COPIED=$((CURSOR_FILES_COPIED + 1))
                else
                    echo "- failed to copy $file to $cursor_config_dir/"
                fi
            fi
        else
            echo "- cursor/$file not found in $dotfiles_dir/cursor"
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

print_step "💾 copying VS Code IDE configs"
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

print_step "💾 copying Zed IDE configs"
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

print_step "👻 copying Ghostty terminal config"
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

print_step "🚀 copying Starship prompt config"
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

print_step "copying Atuin config"
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

print_step "💾 copying Neovim config"
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

print_step "🪿 copying Goose config"
if command -v goose &> /dev/null; then
    copy_goose_settings
    if [ "$DRY_RUN" = true ]; then
        record_step "Goose config" "dry-run" "would copy 3 files"
    else
        record_step "Goose config" "done" "${GOOSE_FILES_COPIED} copied, ${GOOSE_BACKUPS} backed up"
    fi
else
    echo "Goose is not installed. Skipping Goose configuration."
    record_step "Goose config" "skipped" "Goose not installed"
fi

print_step "🖱️  copying Cursor CLI config"
if command -v cursor-agent &> /dev/null; then
    copy_cursor_settings
    if [ "$DRY_RUN" = true ]; then
        record_step "Cursor CLI config" "dry-run" "would copy 2 files"
    else
        record_step "Cursor CLI config" "done" "${CURSOR_FILES_COPIED} copied, ${CURSOR_BACKUPS} backed up"
    fi
else
    echo "Cursor CLI is not installed. Skipping Cursor configuration."
    record_step "Cursor CLI config" "skipped" "Cursor CLI not installed"
fi

print_step "🍎 configuring macOS defaults"
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

print_step "🧹 Cleaning up old backups"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would clean up old backup files, keeping only the 2 most recent."
    record_step "Backup cleanup" "dry-run" "would clean old backups"
else
    # Clean up AGENTS.md backups
    cleanup_backups "$HOME" "AGENTS.md"
    # Clean up Claude settings.json backups
    cleanup_backups "$HOME/.claude" "settings.json"
    cleanup_backups "$HOME/.claude" "mcp.json"
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
    # Clean up Goose config backups
    cleanup_backups "$HOME/.config/goose" "config.yaml"
    cleanup_backups "$HOME/.config/goose" "permission.yaml"
    cleanup_backups "$HOME/.config/goose" ".gooseignore"
    # Clean up Cursor CLI config backups
    cleanup_backups "$HOME/.cursor" "cli-config.json"
    cleanup_backups "$HOME/.cursor" "mcp.json"
    if [ "$BACKUP_DELETED_TOTAL" -eq 0 ]; then
        record_step "Backup cleanup" "done" "nothing to clean"
    else
        record_step "Backup cleanup" "done" "${BACKUP_DELETED_TOTAL} old backups deleted"
    fi
fi

print_step "🔑 Configuring SSH github.com keychain integration"
# Adds a github.com block to ~/.ssh/config with UseKeychain + AddKeysToAgent so
# the SSH key is auto-loaded into the system ssh-agent from macOS keychain on
# first use after reboot/sleep. Intentionally omits IdentityFile so this is
# portable across macs whose default key may be id_rsa, id_ed25519, etc. — ssh
# will try the usual candidates and the keychain directives still do their job.
# Block is delimited with markers so re-runs are idempotent.
SSH_CONFIG="$HOME/.ssh/config"
SSH_MARKER_START="# DOTFILES-MANAGED-START github.com"
SSH_MARKER_END="# DOTFILES-MANAGED-END github.com"
if [ "$DRY_RUN" = true ]; then
    if [ -f "$SSH_CONFIG" ] && grep -qF "$SSH_MARKER_START" "$SSH_CONFIG"; then
        echo "[DRY RUN] github.com block already present (dotfiles-managed) in $SSH_CONFIG"
        record_step "SSH github.com block" "dry-run" "already present (managed)"
    elif [ -f "$SSH_CONFIG" ] && grep -qiE '^[[:space:]]*Host[[:space:]]+([^#]*[[:space:]])?github\.com([[:space:]]|$)' "$SSH_CONFIG"; then
        echo "[DRY RUN] existing manual github.com block detected in $SSH_CONFIG, would skip"
        record_step "SSH github.com block" "dry-run" "manual block present"
    else
        echo "[DRY RUN] Would append github.com block to $SSH_CONFIG"
        record_step "SSH github.com block" "dry-run" "would append"
    fi
else
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if [ ! -f "$SSH_CONFIG" ]; then
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi
    if grep -qF "$SSH_MARKER_START" "$SSH_CONFIG"; then
        echo "- github.com block already present (dotfiles-managed), leaving $SSH_CONFIG untouched"
        record_step "SSH github.com block" "done" "already present (managed)"
    elif grep -qiE '^[[:space:]]*Host[[:space:]]+([^#]*[[:space:]])?github\.com([[:space:]]|$)' "$SSH_CONFIG"; then
        echo "- existing manual github.com block detected in $SSH_CONFIG, leaving it untouched"
        echo "  (to let install.sh manage it, replace it with the dotfiles-marked block)"
        record_step "SSH github.com block" "skipped" "manual block present"
    else
        {
            printf '\n%s\n' "$SSH_MARKER_START"
            printf '# Added by dotfiles install.sh. Enables macOS keychain integration\n'
            printf '# so the SSH key auto-loads on first use after reboot/sleep.\n'
            printf 'Host github.com\n'
            printf '    HostName github.com\n'
            printf '    User git\n'
            printf '    UseKeychain yes\n'
            printf '    AddKeysToAgent yes\n'
            printf '%s\n' "$SSH_MARKER_END"
        } >> "$SSH_CONFIG"
        echo "- appended github.com block to $SSH_CONFIG"
        if command -v ssh-add &> /dev/null && ! ssh-add -l &> /dev/null; then
            echo "- NOTE: ssh-agent has no keys loaded. Seed the keychain once with:"
            echo "    ssh-add --apple-use-keychain ~/.ssh/id_rsa"
            echo "    (or whichever key file lives in ~/.ssh, e.g. id_ed25519)"
        fi
        record_step "SSH github.com block" "done" "appended"
    fi
fi

# ---------------------------------------------------------------------------
# Keep Nuon extensions (install missing from marketplace, then upgrade),
# Claude skills, and Claude plugins current.
# Progress bars advance per item; diffs feed TOOL_UPDATES_CHANGES.
# ---------------------------------------------------------------------------

print_step "Installing and upgrading Nuon CLI extensions"
if ! command -v nuon &> /dev/null; then
    echo "- skipping: nuon not installed"
    record_step "Nuon extensions" "skipped" "nuon not installed"
else
    # Marketplace browse prints a "Found N extension(s)" line before JSON.
    # Prefer --output agent ({ok,data}) and fall back to stripping to the first [/{.
    NUON_BROWSE_RAW=$(nuon extensions browse --output agent 2>/dev/null || true)
    NUON_MISSING=$(python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
# Strip any leading non-JSON banner lines
start = raw.find("{")
if start < 0:
    start = raw.find("[")
if start > 0:
    raw = raw[start:]
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
items = data.get("data") if isinstance(data, dict) else data
if not isinstance(items, list):
    sys.exit(0)
for item in items:
    if not isinstance(item, dict):
        continue
    if item.get("installed"):
        continue
    name = item.get("name") or ""
    repo = item.get("repo") or name
    tag = item.get("latest_tag") or ""
    if name:
        print("%s\t%s\t%s" % (name, repo, tag))
' <<< "$NUON_BROWSE_RAW")
    NUON_MISSING_TOTAL=$(printf '%s\n' "$NUON_MISSING" | awk 'NF' | wc -l | tr -d ' ')

    NUON_LIST_JSON=$(nuon extensions list --output json 2>/dev/null || true)
    NUON_NAMES=$(python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
items = data if isinstance(data, list) else data.get("data", data.get("extensions", []))
if not isinstance(items, list):
    sys.exit(0)
for item in items:
    name = item.get("name") or ""
    ver = item.get("version") or item.get("tag") or "?"
    if name:
        print(f"{name}\t{ver}")
' <<< "$NUON_LIST_JSON")
    NUON_TOTAL=$(printf '%s\n' "$NUON_NAMES" | awk 'NF' | wc -l | tr -d ' ')

    if [ "$NUON_MISSING_TOTAL" -eq 0 ] && [ "$NUON_TOTAL" -eq 0 ]; then
        echo "- no Nuon marketplace extensions found and none installed"
        record_step "Nuon extensions" "skipped" "none available"
    elif [ "$DRY_RUN" = true ]; then
        if [ "$NUON_MISSING_TOTAL" -gt 0 ]; then
            echo "[DRY RUN] Would install $NUON_MISSING_TOTAL marketplace extension(s):"
            while IFS=$'\t' read -r name repo tag; do
                [ -z "$name" ] && continue
                if [ -n "$tag" ]; then
                    echo "  - $name ($repo@$tag)"
                else
                    echo "  - $name ($repo)"
                fi
            done <<< "$NUON_MISSING"
        else
            echo "[DRY RUN] All marketplace extensions already installed"
        fi
        if [ "$NUON_TOTAL" -gt 0 ]; then
            echo "[DRY RUN] Would upgrade $NUON_TOTAL installed Nuon extension(s):"
            while IFS=$'\t' read -r name ver; do
                [ -z "$name" ] && continue
                echo "  - $name ($ver)"
            done <<< "$NUON_NAMES"
        fi
        record_step "Nuon extensions" "dry-run" "would install $NUON_MISSING_TOTAL, upgrade $NUON_TOTAL"
    else
        TOOL_UPDATES_CHANGES+="Nuon extensions:"$'\n'
        NUON_INSTALLED=0
        NUON_UPGRADED=0
        NUON_UNCHANGED=0
        NUON_FAILED=0

        # Install missing marketplace extensions first.
        if [ "$NUON_MISSING_TOTAL" -gt 0 ]; then
            echo "- installing $NUON_MISSING_TOTAL missing marketplace extension(s)"
            NUON_I=0
            while IFS=$'\t' read -r name repo tag; do
                [ -z "$name" ] && continue
                NUON_I=$((NUON_I + 1))
                progress_bar "$NUON_I" "$NUON_MISSING_TOTAL" "install $name"
                # Short name works for nuonco marketplace; use name for install.
                NUON_OUT=$(nuon extensions install "$name" --output agent 2>/dev/null || true)
                if printf '%s' "$NUON_OUT" | grep -Fq '"ok":true'; then
                    NUON_INSTALLED=$((NUON_INSTALLED + 1))
                    progress_clear_line
                    echo "  installed: $name"
                    append_tool_change "installed: $name"
                else
                    NUON_FAILED=$((NUON_FAILED + 1))
                    progress_clear_line
                    echo "  failed: install $name"
                    append_tool_change "failed: install $name"
                fi
            done <<< "$NUON_MISSING"
        else
            echo "- all marketplace extensions already installed"
            append_tool_change "marketplace: all already installed"
        fi

        # Re-list after installs so upgrades cover newly installed extensions.
        NUON_LIST_JSON=$(nuon extensions list --output json 2>/dev/null || true)
        NUON_NAMES=$(python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
items = data if isinstance(data, list) else data.get("data", data.get("extensions", []))
if not isinstance(items, list):
    sys.exit(0)
for item in items:
    name = item.get("name") or ""
    ver = item.get("version") or item.get("tag") or "?"
    if name:
        print(f"{name}\t{ver}")
' <<< "$NUON_LIST_JSON")
        NUON_TOTAL=$(printf '%s\n' "$NUON_NAMES" | awk 'NF' | wc -l | tr -d ' ')

        if [ "$NUON_TOTAL" -eq 0 ]; then
            NUON_DETAIL="${NUON_INSTALLED} installed, 0 upgraded, ${NUON_FAILED} failed"
            if [ "$NUON_FAILED" -gt 0 ]; then
                record_step "Nuon extensions" "failed" "$NUON_DETAIL"
            else
                record_step "Nuon extensions" "done" "$NUON_DETAIL"
            fi
            echo "- $NUON_DETAIL"
        else
            NUON_I=0
            # bash 3.2 has no associative arrays on macOS default bash — use temp files
            NUON_BEFORE_FILE=$(mktemp -t nuon-before.XXXXXX)
            NUON_AFTER_FILE=$(mktemp -t nuon-after.XXXXXX)
            printf '%s\n' "$NUON_NAMES" > "$NUON_BEFORE_FILE"
            while IFS=$'\t' read -r name ver; do
                [ -z "$name" ] && continue
                NUON_I=$((NUON_I + 1))
                progress_bar "$NUON_I" "$NUON_TOTAL" "upgrade $name ($ver)"
                # Per-name upgrade exits 1 when already latest; treat that as success.
                NUON_OUT=$(nuon extensions upgrade "$name" --output agent 2>/dev/null || true)
                if printf '%s' "$NUON_OUT" | grep -Fq '"error"'; then
                    if printf '%s' "$NUON_OUT" | grep -Fq 'already at the latest'; then
                        :
                    else
                        NUON_FAILED=$((NUON_FAILED + 1))
                        progress_clear_line
                        echo "  failed: $name (was $ver)"
                        append_tool_change "failed: $name (was $ver; upgrade error)"
                    fi
                fi
            done <<< "$NUON_NAMES"
            NUON_LIST_AFTER=$(nuon extensions list --output json 2>/dev/null || true)
            python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
items = data if isinstance(data, list) else data.get("data", data.get("extensions", []))
if not isinstance(items, list):
    sys.exit(0)
for item in items:
    name = item.get("name") or ""
    ver = item.get("version") or item.get("tag") or "?"
    if name:
        print(f"{name}\t{ver}")
' <<< "$NUON_LIST_AFTER" > "$NUON_AFTER_FILE"
            while IFS=$'\t' read -r name before_ver; do
                [ -z "$name" ] && continue
                after_ver=$(awk -F'\t' -v n="$name" '$1==n {print $2; exit}' "$NUON_AFTER_FILE")
                after_ver="${after_ver:-?}"
                if printf '%s' "$TOOL_UPDATES_CHANGES" | grep -Fq "failed: $name "; then
                    continue
                fi
                # Newly installed this run: already counted under installed.
                if printf '%s' "$TOOL_UPDATES_CHANGES" | grep -Fq "installed: $name"; then
                    continue
                fi
                if [ "$before_ver" != "$after_ver" ]; then
                    NUON_UPGRADED=$((NUON_UPGRADED + 1))
                    report_upgrade "$name" "$before_ver" "$after_ver"
                else
                    NUON_UNCHANGED=$((NUON_UNCHANGED + 1))
                    append_tool_change "unchanged: $name ($before_ver)"
                fi
            done < "$NUON_BEFORE_FILE"
            rm -f "$NUON_BEFORE_FILE" "$NUON_AFTER_FILE"
            NUON_DETAIL="${NUON_INSTALLED} installed, ${NUON_UPGRADED} upgraded, ${NUON_UNCHANGED} unchanged, ${NUON_FAILED} failed"
            if [ "$NUON_FAILED" -gt 0 ]; then
                record_step "Nuon extensions" "failed" "$NUON_DETAIL"
            else
                record_step "Nuon extensions" "done" "$NUON_DETAIL"
            fi
            echo "- $NUON_DETAIL"
        fi
    fi
fi

print_step "Updating Claude skills"
if ! command -v npx &> /dev/null; then
    echo "- skipping: npx not installed"
    record_step "Claude skills" "skipped" "npx not installed"
else
    SKILLS_JSON=$(npx --yes skills list -g --json 2>/dev/null || true)
    SKILLS_ROWS=$(python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
if not isinstance(data, list):
    sys.exit(0)
for item in data:
    name = item.get("name") or ""
    source = item.get("source") or ""
    if name:
        remote = "1" if source else "0"
        label = source if source else "local"
        print("%s\t%s\t%s" % (name, label, remote))
' <<< "$SKILLS_JSON")
    SKILLS_TOTAL=$(printf '%s\n' "$SKILLS_ROWS" | awk 'NF' | wc -l | tr -d ' ')
    if [ "$SKILLS_TOTAL" -eq 0 ]; then
        echo "- no global Claude skills installed"
        record_step "Claude skills" "skipped" "none installed"
    elif [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would check/update $SKILLS_TOTAL skill(s):"
        while IFS=$'\t' read -r name source remote; do
            [ -z "$name" ] && continue
            cur=$(python3 -c '
import json, os, sys, hashlib
name, skills_json = sys.argv[1], sys.argv[2]
ver = ""
lock_path = os.path.expanduser("~/.agents/.skill-lock.json")
if os.path.isfile(lock_path):
    try:
        with open(lock_path) as f:
            lock = json.load(f).get("skills") or {}
        if name in lock and lock[name].get("skillFolderHash"):
            ver = lock[name]["skillFolderHash"][:12]
    except Exception:
        pass
if not ver:
    try:
        data = json.loads(skills_json) if skills_json else []
    except Exception:
        data = []
    for item in data if isinstance(data, list) else []:
        if item.get("name") != name:
            continue
        path = item.get("path") or ""
        if path and os.path.isdir(path):
            h = hashlib.sha256()
            for root, _, files in os.walk(path):
                for f in sorted(files):
                    fp = os.path.join(root, f)
                    try:
                        with open(fp, "rb") as fh:
                            h.update(fh.read())
                    except OSError:
                        pass
            ver = h.hexdigest()[:12]
        break
print(ver or "?")
' "$name" "$SKILLS_JSON")
            if [ "$remote" = "1" ]; then
                echo "  - $name (update from $source, current $cur)"
            else
                echo "  - $name (local $cur, skip remote update)"
            fi
        done <<< "$SKILLS_ROWS"
        record_step "Claude skills" "dry-run" "would check $SKILLS_TOTAL"
    else
        TOOL_UPDATES_CHANGES+="Claude skills:"$'\n'
        SKILLS_UPGRADED=0
        SKILLS_UNCHANGED=0
        SKILLS_SKIPPED=0
        SKILLS_FAILED=0
        SKILLS_I=0
        SKILLS_BEFORE_FILE=$(mktemp -t skills-before.XXXXXX)
        # Prefer skill-lock folder hashes; fall back to content digest of the skill path.
        python3 -c '
import json, sys, os, hashlib
raw = sys.stdin.read().strip()
data = json.loads(raw) if raw else []
lock_path = os.path.expanduser("~/.agents/.skill-lock.json")
lock = {}
if os.path.isfile(lock_path):
    try:
        with open(lock_path) as f:
            lock = json.load(f).get("skills") or {}
    except Exception:
        lock = {}
for item in data if isinstance(data, list) else []:
    name = item.get("name") or ""
    path = item.get("path") or ""
    source = item.get("source") or "local"
    ver = ""
    if name in lock and lock[name].get("skillFolderHash"):
        ver = lock[name]["skillFolderHash"][:12]
    elif path and os.path.isdir(path):
        h = hashlib.sha256()
        for root, _, files in os.walk(path):
            for f in sorted(files):
                fp = os.path.join(root, f)
                try:
                    with open(fp, "rb") as fh:
                        h.update(fh.read())
                except OSError:
                    pass
        ver = h.hexdigest()[:12]
    if name:
        print("%s\t%s\t%s" % (name, source, ver or "?"))
' <<< "$SKILLS_JSON" > "$SKILLS_BEFORE_FILE"
        while IFS=$'\t' read -r name source remote; do
            [ -z "$name" ] && continue
            SKILLS_I=$((SKILLS_I + 1))
            before_ver=$(awk -F'\t' -v n="$name" '$1==n {print $3; exit}' "$SKILLS_BEFORE_FILE")
            before_ver="${before_ver:-?}"
            progress_bar "$SKILLS_I" "$SKILLS_TOTAL" "$name ($before_ver)"
            if [ "$remote" != "1" ]; then
                SKILLS_SKIPPED=$((SKILLS_SKIPPED + 1))
                append_tool_change "skipped: $name (local, $before_ver)"
                continue
            fi
            if npx --yes skills update "$name" -g -y >/dev/null 2>&1; then
                after_ver=$(python3 -c '
import json, sys, os, hashlib
name = sys.argv[1]
lock_path = os.path.expanduser("~/.agents/.skill-lock.json")
ver = ""
if os.path.isfile(lock_path):
    try:
        with open(lock_path) as f:
            lock = json.load(f).get("skills") or {}
        if name in lock and lock[name].get("skillFolderHash"):
            ver = lock[name]["skillFolderHash"][:12]
    except Exception:
        pass
if not ver:
    # Fall back to hashing the skill path from a fresh list
    pass
print(ver)
' "$name")
                if [ -z "$after_ver" ]; then
                    after_json=$(npx --yes skills list -g --json 2>/dev/null || true)
                    after_ver=$(python3 -c '
import json, sys, os, hashlib
name = sys.argv[1]
raw = sys.stdin.read().strip()
data = json.loads(raw) if raw else []
for item in data if isinstance(data, list) else []:
    if item.get("name") != name:
        continue
    path = item.get("path") or ""
    if path and os.path.isdir(path):
        h = hashlib.sha256()
        for root, _, files in os.walk(path):
            for f in sorted(files):
                fp = os.path.join(root, f)
                try:
                    with open(fp, "rb") as fh:
                        h.update(fh.read())
                except OSError:
                    pass
        print(h.hexdigest()[:12])
    break
' "$name" <<< "$after_json")
                fi
                after_ver="${after_ver:-?}"
                if [ "$before_ver" != "$after_ver" ]; then
                    SKILLS_UPGRADED=$((SKILLS_UPGRADED + 1))
                    report_upgrade "$name" "$before_ver" "$after_ver"
                else
                    SKILLS_UNCHANGED=$((SKILLS_UNCHANGED + 1))
                    append_tool_change "unchanged: $name ($before_ver)"
                fi
            else
                SKILLS_FAILED=$((SKILLS_FAILED + 1))
                progress_clear_line
                echo "  failed: $name (was $before_ver)"
                append_tool_change "failed: $name (was $before_ver; update exit non-zero)"
            fi
        done <<< "$SKILLS_ROWS"
        rm -f "$SKILLS_BEFORE_FILE"
        SKILLS_DETAIL="${SKILLS_UPGRADED} upgraded, ${SKILLS_UNCHANGED} unchanged, ${SKILLS_SKIPPED} skipped, ${SKILLS_FAILED} failed"
        if [ "$SKILLS_FAILED" -gt 0 ]; then
            record_step "Claude skills" "failed" "$SKILLS_DETAIL"
        else
            record_step "Claude skills" "done" "$SKILLS_DETAIL"
        fi
        echo "- $SKILLS_DETAIL"
    fi
fi

print_step "Updating Claude plugins"
if ! command -v claude &> /dev/null; then
    echo "- skipping: claude not installed"
    record_step "Claude plugins" "skipped" "claude not installed"
else
    PLUGINS_JSON=$(claude plugin list --json 2>/dev/null || true)
    PLUGINS_ROWS=$(python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
if not isinstance(data, list):
    sys.exit(0)
for item in data:
    pid = item.get("id") or ""
    ver = item.get("version") or "?"
    if pid:
        print(f"{pid}\t{ver}")
' <<< "$PLUGINS_JSON")
    PLUGINS_TOTAL=$(printf '%s\n' "$PLUGINS_ROWS" | awk 'NF' | wc -l | tr -d ' ')
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would update Claude marketplaces, then $PLUGINS_TOTAL plugin(s):"
        while IFS=$'\t' read -r pid ver; do
            [ -z "$pid" ] && continue
            echo "  - $pid ($ver)"
        done <<< "$PLUGINS_ROWS"
        record_step "Claude plugins" "dry-run" "would update marketplaces + $PLUGINS_TOTAL plugins"
    else
        TOOL_UPDATES_CHANGES+="Claude plugins:"$'\n'
        PLUGINS_UPGRADED=0
        PLUGINS_UNCHANGED=0
        PLUGINS_FAILED=0
        echo "- refreshing marketplaces..."
        progress_bar 1 1 "marketplaces"
        if ! claude plugin marketplace update >/dev/null 2>&1; then
            append_tool_change "failed: marketplace update (exit non-zero)"
            PLUGINS_FAILED=$((PLUGINS_FAILED + 1))
        else
            append_tool_change "refreshed: marketplaces"
        fi
        if [ "$PLUGINS_TOTAL" -eq 0 ]; then
            echo "- no Claude plugins installed"
            if [ "$PLUGINS_FAILED" -gt 0 ]; then
                record_step "Claude plugins" "failed" "marketplace failed, 0 plugins"
            else
                record_step "Claude plugins" "done" "marketplaces refreshed, 0 plugins"
            fi
        else
            PLUGINS_BEFORE_FILE=$(mktemp -t plugins-before.XXXXXX)
            printf '%s\n' "$PLUGINS_ROWS" > "$PLUGINS_BEFORE_FILE"
            PLUGINS_I=0
            while IFS=$'\t' read -r pid ver; do
                [ -z "$pid" ] && continue
                PLUGINS_I=$((PLUGINS_I + 1))
                progress_bar "$PLUGINS_I" "$PLUGINS_TOTAL" "$pid ($ver)"
                if claude plugin update "$pid" -y >/dev/null 2>&1; then
                    :
                else
                    PLUGINS_FAILED=$((PLUGINS_FAILED + 1))
                    progress_clear_line
                    echo "  failed: $pid (was $ver)"
                    append_tool_change "failed: $pid (was $ver; update exit non-zero)"
                fi
            done <<< "$PLUGINS_ROWS"
            PLUGINS_AFTER_JSON=$(claude plugin list --json 2>/dev/null || true)
            PLUGINS_AFTER_FILE=$(mktemp -t plugins-after.XXXXXX)
            python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)
if not isinstance(data, list):
    sys.exit(0)
for item in data:
    pid = item.get("id") or ""
    ver = item.get("version") or "?"
    if pid:
        print(f"{pid}\t{ver}")
' <<< "$PLUGINS_AFTER_JSON" > "$PLUGINS_AFTER_FILE"
            while IFS=$'\t' read -r pid before_ver; do
                [ -z "$pid" ] && continue
                if printf '%s' "$TOOL_UPDATES_CHANGES" | grep -Fq "failed: $pid "; then
                    continue
                fi
                after_ver=$(awk -F'\t' -v n="$pid" '$1==n {print $2; exit}' "$PLUGINS_AFTER_FILE")
                after_ver="${after_ver:-?}"
                if [ "$before_ver" != "$after_ver" ]; then
                    PLUGINS_UPGRADED=$((PLUGINS_UPGRADED + 1))
                    report_upgrade "$pid" "$before_ver" "$after_ver"
                else
                    PLUGINS_UNCHANGED=$((PLUGINS_UNCHANGED + 1))
                    append_tool_change "unchanged: $pid ($before_ver)"
                fi
            done < "$PLUGINS_BEFORE_FILE"
            rm -f "$PLUGINS_BEFORE_FILE" "$PLUGINS_AFTER_FILE"
            PLUGINS_DETAIL="${PLUGINS_UPGRADED} upgraded, ${PLUGINS_UNCHANGED} unchanged, ${PLUGINS_FAILED} failed"
            if [ "$PLUGINS_FAILED" -gt 0 ]; then
                record_step "Claude plugins" "failed" "$PLUGINS_DETAIL"
            else
                record_step "Claude plugins" "done" "$PLUGINS_DETAIL"
            fi
            echo "- $PLUGINS_DETAIL"
        fi
    fi
fi

print_step "🔄 Keeping sibling repos current (repo-current)"
# Resolve the parent of dotfiles to a clean absolute path so the displayed
# repo-current location doesn't include a literal "..".
REPO_CURRENT_PARENT="$(cd "$DOTFILES_PATH/.." && pwd)"
REPO_CURRENT_DIR="$REPO_CURRENT_PARENT/repo-current"
REPO_CURRENT_SCRIPT="$REPO_CURRENT_DIR/git_pull_all.sh"
REPO_CURRENT_URL="https://github.com/sharkymark/repo-current.git"
REPO_CURRENT_FRESH_CLONE=false
# Hardcoded default scan path. Stored as a literal string with $HOME so
# git_pull_all.sh expands it at read time. Edit directories.txt after the
# first run if your dev tree lives somewhere else on a given Mac.
REPO_CURRENT_PREFERRED_PATH='$HOME/src'

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
    # With --show-repo-path, also build a repo-name -> full-path map (with $HOME
    # collapsed to ~) so we can rewrite git_pull_all.sh's basename-only output
    # to show each repo's full directory path.
    REPO_CURRENT_VALID=0
    REPO_CURRENT_INVALID=0
    REPO_CURRENT_MAP=""
    [ "$SHOW_REPO_PATH" = true ] && REPO_CURRENT_MAP=$(mktemp -t repo-current-map.XXXXXX)
    if [ -f "$REPO_CURRENT_DIRS_FILE" ]; then
        while IFS= read -r raw || [ -n "$raw" ]; do
            case "$raw" in ''|\#*) continue;; esac
            expanded=$(eval echo "$raw")
            if [ -d "$expanded" ]; then
                REPO_CURRENT_VALID=$((REPO_CURRENT_VALID + 1))
                if [ "$SHOW_REPO_PATH" = true ]; then
                    while IFS= read -r -d '' repo_dir; do
                        repo_name=$(basename "$repo_dir")
                        case "$repo_dir" in
                            "$HOME"/*) display_path="~${repo_dir#$HOME}" ;;
                            *) display_path="$repo_dir" ;;
                        esac
                        printf '%s\t%s\n' "$repo_name" "$display_path" >> "$REPO_CURRENT_MAP"
                    done < <(find "$expanded" -type d \( -exec test -e {}/.git \; \) -prune -print0 2>/dev/null)
                fi
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
        # Run repo-current non-interactively so missing creds fail fast instead
        # of hanging. git_pull_all.sh wraps each `git pull` in $(...) which makes
        # stderr non-tty, so any HTTPS-credential or SSH-passphrase prompt would
        # silently block on stdin we can't see. These env vars prevent the prompts:
        #   GIT_TERMINAL_PROMPT=0        -> git won't ask for username/password
        #   ssh -o BatchMode=yes         -> ssh won't ask for a passphrase
        #   ssh -o StrictHostKeyChecking=accept-new -> auto-accept first-time host keys
        # Repos that need creds will be reported under "Other problems" instead.
        # Stream output live via tee so the user sees progress; the tempfile
        # keeps the full transcript for the summary parser below.
        REPO_CURRENT_TMP=$(mktemp -t repo-current-out.XXXXXX)
        ( cd "$REPO_CURRENT_DIR" && \
          GIT_TERMINAL_PROMPT=0 \
          GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new" \
          bash ./git_pull_all.sh --summary-only ) 2>&1 | tee "$REPO_CURRENT_TMP"
        REPO_CURRENT_RC=${PIPESTATUS[0]}
        REPO_CURRENT_OUT=$(cat "$REPO_CURRENT_TMP")
        rm -f "$REPO_CURRENT_TMP"
        if [ "$SHOW_REPO_PATH" = true ]; then
            # Rewrite "  - <repo>  <url>" lines inside AFFECTED REPOSITORIES to
            # "  - <full-path>  <url>" so each repo's location is unambiguous.
            REPO_CURRENT_OUT=$(printf '%s\n' "$REPO_CURRENT_OUT" | awk -v map="$REPO_CURRENT_MAP" '
                BEGIN {
                    while ((getline line < map) > 0) {
                        tab = index(line, "\t")
                        if (tab > 0) m[substr(line, 1, tab - 1)] = substr(line, tab + 1)
                    }
                    close(map)
                }
                /^=== AFFECTED REPOSITORIES ===/ { in_affected = 1 }
                /^Finished processing directories\./ { in_affected = 0 }
                {
                    if (in_affected && substr($0, 1, 4) == "  - ") {
                        rest = substr($0, 5)
                        sp = index(rest, " ")
                        if (sp > 0) { name = substr(rest, 1, sp - 1); tail = substr(rest, sp) }
                        else        { name = rest; tail = "" }
                        if (name in m) { print "  - " m[name] tail; next }
                    }
                    print
                }
            ')
        fi
        # Output was already streamed live above via tee; do not re-print here.
        # The --show-repo-path rewrites still flow into REPO_CURRENT_CHANGES and
        # appear (with full paths) in the end-of-run "Repo-current changes:" block.
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
    [ -n "$REPO_CURRENT_MAP" ] && rm -f "$REPO_CURRENT_MAP"
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
echo "Tool updates:"
if [ -z "$TOOL_UPDATES_CHANGES" ]; then
    echo "  (not run, or no changes)"
else
    printf '%s' "$TOOL_UPDATES_CHANGES"
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
INSTALL_COMPLETED="$(now_stamp)"
echo "Started:   $INSTALL_STARTED"
echo "Completed: $INSTALL_COMPLETED"
echo ""
