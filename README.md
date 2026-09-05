# Dotfiles

Personal configuration files for development tools and shell environments.

## Installation

**Preview changes (dry run):**
```bash
./install.sh --dry-run
```

This shows what files would be copied without actually modifying anything. Useful for:
- Seeing what will change before running
- Verifying the script on a new machine
- Checking current git settings

**Install dotfiles:**
```bash
./install.sh
```

This script copies configuration files to their appropriate locations:

- Git global ignore (`.gitignore_global`)
- Shell configs (bash, zsh, fish)
- VS Code settings and extensions (if installed)
- Zed editor settings and keymap (if installed)
- Prettier formatting config
- Ghostty terminal config (if installed)
- Starship prompt config (if installed)
- Goose config (if installed)
- Cursor CLI config and MCP servers (if installed)

On macOS, also runs Homebrew package installation and system defaults.

Each run also installs any missing Nuon CLI extensions from the marketplace, upgrades
installed ones, updates global Claude skills (via `npx skills`), and refreshes Claude
plugin marketplaces plus installed plugins, with a progress bar and a Tool updates
section in the final summary.

## Goose Configuration

The vendored `goose/config.yaml` has no provider or model pinned — pass them as
environment variables at launch instead:

```bash
GOOSE_PROVIDER=ollama GOOSE_MODEL=qwen2.5:14b-instruct goose
```

Goose reads the available model list live from the Ollama server, so any model
you've pulled shows up without editing config. Pull the models you want to use:

```bash
ollama pull qwen2.5:7b-instruct
ollama pull llama3.1:8b
ollama pull qwen2.5:14b-instruct
ollama pull qwen3-coder:30b
```

## Post-Installation: Git Configuration

After running `install.sh`, you need to configure your git identity **manually on each machine**. This allows you to use different emails for work vs personal laptops.

### Required: Set Your Identity

```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

Examples:
- **Work laptop:** `git config --global user.email "mark@nuon.co"`
- **Personal laptop:** `git config --global user.email "mtm20176@gmail.com"`

### Optional: Enable GPG Commit Signing

If you want to sign your commits with GPG:

1. **Check if you have GPG keys:**
   ```bash
   gpg --list-secret-keys --keyid-format=long
   ```

2. **If you don't have a key, generate one:**
   ```bash
   gpg --full-generate-key
   ```

3. **Configure git to use your key:**
   ```bash
   git config --global user.signingkey YOUR_KEY_ID
   git config --global commit.gpgsign true
   ```

4. **Add your GPG key to GitHub:**
   ```bash
   gpg --armor --export YOUR_KEY_ID
   ```
   Copy the output and add it to GitHub: Settings → SSH and GPG keys → New GPG key

### Why Manual Configuration?

The dotfiles contain **behavior and preferences** (shell aliases, editor settings, etc.) but NOT **identity settings** (name, email, signing keys). This prevents:
- Accidentally overwriting work git settings
- Breaking GPG signing on machines without your keys
- Using the wrong email on different machines

Each machine can have its own identity configuration while sharing the same convenient development environment.

## License

MIT License - Copyright (c) 2026 Mark Milligan
