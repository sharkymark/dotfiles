# Dotfiles Repository

This repository contains configuration files for various development tools and shell environments.

## Features

- **Git Configuration**
  - Global .gitconfig with user info and settings
  - Global .gitignore_global for common ignored files
- **Shell Configurations**
  - Bash: Custom prompt, history settings
  - Fish: Custom prompt with Git and Python virtualenv support
  - Zsh: Custom prompt, enhanced history settings
- **VS Code Settings**
  - Editor preferences (theme, word wrap, intellisense)
  - Terminal and Git integration
  - Copilot configuration
- **Zed IDE Settings**
  - Automatically copies Zed IDE settings if installed
- **Prettier Configuration**
  - Global .prettierrc for consistent code formatting
- **Homebrew Setup**
  - Automatic installation of Homebrew if not present
  - Package installation via Brewfile
- **macOS Configuration**
  - Custom macOS system defaults
  - Finder and mouse settings
- **AI Code Generation Tools**
  - Aider configuration for AI-assisted coding
  - Block Goose configuration for AI code generation
- **Installation Script**
  - Automatically detects and configures appropriate shell
  - Sets up VS Code and Zed settings if installed
  - Configures Homebrew packages and macOS defaults

## Installation

1. Clone this repository
2. Run the installation script:
   ```bash
   ./install.sh
   ```

This script will:

- Copy common Git configuration (`.gitconfig`, `.gitignore_global`).
- Copy Prettier configuration (`.prettierrc`).
- Copy shell configurations for Bash, Zsh, and Fish (if installed).
- Copy VS Code settings and extensions (if installed).
- Copy Zed editor settings and keymap (if installed).
- Copy Aider configuration.
- Copy Block Goose configuration (if `$HOME/.config/goose` directory exists).\*\*
- On macOS:
  - Run `brew/brew.sh` to install Homebrew packages.
  - Run `mac/macos.sh` to apply macOS system defaults.

## File Structure

```
.
├── install.sh               # Main installation script
├── ai-agents/               # AI agent configurations
│   ├── .original-aider.conf.yml # Source Aider config
│   └── .original-goose-config.yaml # Source Goose config
├── brew/
│   └── Brewfile            # Homebrew packages and casks
│   └── brew.sh              # Homebrew installation script
├── code/
│   ├── settings.json        # VS Code settings
│   └── extensions.json      # VS Code extensions
├── git/
│   ├── .gitconfig           # Git configuration
│   └── .gitignore_global    # Global gitignore patterns
├── mac/
│   └── macos.sh         # macOS system preferences
├── prettier/
│   └── .prettierrc         # Prettier formatting config
├── zed/
│   ├── settings.json        # Zed IDE settings
│   └── keymap.json          # Zed IDE keymap
└── shell/
    ├── bash/
    │   ├── .bash_profile    # Bash profile (sources .bashrc)
    │   └── .bashrc          # Bash configuration
    ├── fish/
    │   └── config.fish      # Fish shell configuration
    └── zsh/
        └── .zshrc           # Zsh configuration
```

## Zed IDE Settings

This script now supports copying Zed IDE settings and keymaps. If Zed is installed, the script will:

1. Check if `./zed/settings.json` exists in the dotfiles directory and copy it to `~/.config/zed/settings.json`.
2. Check if `./zed/keymap.json` exists in the dotfiles directory and copy it to `~/.config/zed/keymap.json`.

Ensure that both `zed/settings.json` and `zed/keymap.json` files are present in the dotfiles directory before running the script.

## VS Code Settings

The `install.sh` script now includes functionality to copy both `settings.json` and `extensions.json` for Visual Studio Code. Here's how it works:

1. The script checks if the `$HOME/.vscode` directory exists. If it does not, it prompts the user to ensure Visual Studio Code is installed.
2. If the directory exists, the script copies:
   - `settings.json` to `$HOME/Library/Application Support/Code/User/settings.json`
   - `extensions.json` to `$HOME/.vscode/extensions.json`

If either file is missing in the `code` directory of the repository, the script will notify the user.

## AI Code Generation Tools

The `.gitignore` file has been updated to include entries for AI code generation tools. This ensures that temporary or generated files from these tools are not accidentally committed to the repository. If you are using any AI tools for code generation, make sure to review the `.gitignore` file to confirm that the relevant entries are included.

### AI Agent Configurations

- **Aider:** Copies the configuration file from `ai-agents/.original-aider.conf.yml` to `$HOME/.aider.conf.yml`.
- **Block Goose:** Copies the configuration file from `ai-agents/.original-goose-config.yaml` to `$HOME/.config/goose/config.yaml`. The script checks if the `$HOME/.config/goose` directory exists first; if not, it prompts the user to install Goose.

## Resources

- [GitHub](https://github.com)
- [Fish Shell](https://fishshell.com)
- [VS Code IDE](https://code.visualstudio.com)
- [Dotfiles GitHub](https://dotfiles.github.io)

## License

MIT License

Copyright (c) 2024 Mark Milligan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
