Codex permission prompt settings
- [x] Compare Codex defaults with Cursor and Claude permissions
- [x] Verify supported approval and sandbox settings in official OpenAI documentation
- [x] Set no-prompt command execution and approval for configured MCP servers
- [x] Save preference in indexed persistent memory and shared instructions
- [x] Validate config with Codex and deploy the settings to the local Codex config

Codex permissions review
- Before: on-request command approvals, workspace-write sandbox, no server-wide MCP approval defaults.
- After: never command approvals, danger-full-access sandbox, approve defaults on all five configured MCP servers.
- Codex 0.162.1 loaded the repository config and deployed config with mcp list; git diff --check passed. Strict-config is unsupported for mcp commands, so strict validation was unavailable.
- Backed up local config and shared instructions before updating them; preserved existing local per-tool approvals. Restart required for existing sessions. No commits or pushes.

# Fix /mcp Errors from Slack and Unauthenticated Endpoints

- [x] Wrap nuon-byoc and nuonco Slack MCP commands in zsh to expand environment variables
- [x] Mark unauthenticated HTTP MCP servers and shark-local as disabled in ai/mcp_config.json
- [x] Sync updated ai/mcp_config.json to ~/.gemini/config/mcp_config.json
- [x] Verify agy mcp list and verify Slack servers initialize cleanly without errors

## Review
- Diagnosed Slack MCP crashes: Antigravity does not expand environment variables in the env map, passing literal strings that caused authentication failures and Node.js stack traces. Fixed by wrapping the invocation in /bin/zsh -c.
- Diagnosed HTTP 401 and connection refused errors: remote endpoints (pylon, superhuman-mail, grain, linear, airtable, lovable, notion) require OAuth/tokens, and shark-local is not running locally. Marked them disabled in Antigravity MCP config so /mcp does not attempt initialization.
- Synced ai/mcp_config.json to ~/.gemini/config/mcp_config.json.
