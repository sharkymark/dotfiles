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
- Starship prompt config (if installed), including Nuon `[custom.nuon]` (needs https://github.com/nuonco/nuon-ext-starship; install warns if the extension binary is missing)
- Cursor CLI config and MCP servers (if installed)
- Codex settings, MCP servers, and shared agent instructions
- Amp MCP servers (if installed)

On macOS, also runs Homebrew package installation and system defaults.

Each run also installs any missing Nuon CLI extensions from the marketplace, upgrades
installed ones, updates global Claude skills (via `npx skills`), and refreshes Claude
plugin marketplaces plus installed plugins, with a progress bar and a Tool updates
section in the final summary.

## Codex Configuration

`codex/config.toml` is copied to `~/.codex/config.toml` (or `$CODEX_HOME/config.toml`
when set). Existing configuration and instructions are backed up before replacement.
The installer links Codex's `AGENTS.md` to the shared `~/AGENTS.md`. Only these files
are deployed; authentication and session files stay local. Reconcile any local
settings you want to retain before running the installer.

Configured MCP servers match Cursor and Claude Code, plus OpenAI developer
documentation: Nuon, shark-local, Grain, Superhuman Mail, both Slack workspaces,
Plausible Analytics, Salesforce DX, Pylon, Linear, Airtable, Lovable, Notion, and
AWS MCP. Nuon retains the existing `--allow-writes` setting.
Codex uses `approval_policy = "never"` and `sandbox_mode = "danger-full-access"`
for command execution without approval prompts and with full filesystem/network
access. All configured MCP servers use `default_tools_approval_mode = "approve"`,
matching the Nuon, shark-local, and Slack permissions in Cursor and Claude.
Restart Codex after installing; managed policies or app-specific overrides may
still take precedence over these defaults.
Slack uses `npx`, so Node.js must be available on Codex's PATH. shark-local requires
its service to be running at `http://127.0.0.1:8000/mcp`.
Grain uses the legacy `mcp-remote` bridge because native Codex OAuth login rejects
Grain’s cross-origin authorization metadata. The bridge handles browser login and
keeps its credentials locally; `codex mcp login grain` does not apply to this stdio server.
Lovable also uses `mcp-remote` to work around native Codex OAuth discovery;
the bridge stores its OAuth credentials locally.
For Airtable login, use `codex mcp login airtable --oauth-client-registration dcr`;
the default URL-based client registration was rejected by Airtable.

Export these variables in the environment that launches Codex; no token values
belong in the repository:

- `SLACK_MCP_XOXC_TOKEN_NUON_BYOC`
- `SLACK_MCP_XOXD_TOKEN_NUON_BYOC`
- `SLACK_MCP_XOXC_TOKEN_NUONCO`
- `SLACK_MCP_XOXD_TOKEN_NUONCO`
- `PLAUSIBLE_API_KEY`

Each Slack launcher maps its workspace variables to the server's expected token
names and fails with a clear message if a token is missing. Restart Codex after
installation, check `codex mcp list`, then verify a read call in each Slack workspace.
GUI launches also need access to the token variables and Node.js PATH.

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
