Workflow Orchestration
Read ~/src/mark/dotfiles/ai/memory/MEMORY.md at session start and apply its indexed lessons.
That memory directory is gitignored and local-only; never commit lesson files.

1. Plan Mode Default — plan for architectural, multi-file, or hard-to-reverse changes; skip for small/obvious edits. If sideways, STOP and re-plan. Plan verification too. Write specs upfront.
2. Subagent Strategy — use subagents liberally; one tack each; offload research and parallel analysis.
3. Self-Improvement Loop — after ANY user correction, save a lesson to persistent project memory (a memory file plus its MEMORY.md index line).
4. Verification Before Done — small edits: run the relevant lint/format/test for what you touched only. Multi-file or behavior changes: prove with a focused test, log, or quick check — not full-repo CI unless CI is already failing.
5. Demand Elegance (Balanced) — skip for obvious fixes. For non-trivial work, prefer the elegant fix over a hack.
6. Autonomous Bug Fixing — fix from logs/errors/failing tests; do not ask for hand-holding. Fix failing CI without being told how.

Specialized instructions (read when the task fits; do not paste up front). Prefer the local path; if missing, use the GitHub URL:
- Nuon app configs: ~/src/mark/dotfiles/ai/nuon-app-AGENTS.md (else https://github.com/sharkymark/dotfiles/blob/main/ai/nuon-app-AGENTS.md)
- Revenue / Salesforce / meetings: ~/src/mark/dotfiles/ai/revenue-AGENTS.md (else https://github.com/sharkymark/dotfiles/blob/main/ai/revenue-AGENTS.md)
- Nuon platform understanding: Shark nuon-oss + nuon-docs (read-only unless asked to change OSS)

Cursor (primary)
Default: Auto with Cost. Do not manually pick Composer, Grok, or Claude unless Mark asks. Prefer Cursor Models pool (Composer 2.5 / Cursor Grok); escalate to Balance/Intelligence only for a hard task, then drop back to Cost. Plan mode for architectural/ambiguous work. Explore/mechanical subagents: Composer 2.5 via cli-config subagentModels. Prefer Grok over Composer for research, CRM, and meeting analysis when Auto Cost can choose. Keep attributeCommitsToAgent and attributePRsToAgent false.

Other agents (Claude Code, Codex, Gemini)
Use the session's planning model for design/hard reasoning; cheaper/faster for mechanical subagent work. Do not escalate above the session tier. For Gemini/Antigravity: Google AI Pro; prefer native read/search tools over shell to avoid permission popups; keep MCP mirrors in ai/mcp_config.json / ai/gemini_settings.json.

Task tracking
Use the client's todo/plan tools. Capture lessons in persistent project memory.

Core Principles
Simplicity First. No Laziness (root causes). Minimal Impact (touch only what is needed).

Language and Tooling Defaults
These apply when a repo has no CLAUDE.md/AGENTS.md of its own. A repo-level file always overrides this section.

Git and commits:
- do not commit or push unless I ask; if on a default branch, branch first
- name every new branch mm/<short-description> (kebab-case); same for worktrees — rename before first commit
- prefer small, focused commits; keep messages and PR titles/bodies to the point
- never add Co-authored-by, Made-with, or any AI/agent/bot attribution to commits or PRs
- never set git author/committer to an agent identity; commits must use the human user only
- do not install hooks to strip attribution; fix at the source (agent behavior + Cursor settings)
- if attribution was already pushed, rewrite messages and force-push only on feature branches I own, with --force-with-lease

Go:
- gofmt/goimports; go vet on touched packages
- test/build the packages you changed (not go test ./... unless the change is broad); keep go.mod module path correct
- handle every error; no panic for control flow

Python:
- prefer uv; else repo venv/requirements.txt
- ruff format + ruff check on touched files; pytest for the area you changed; run in the repo venv, not system Python

TypeScript / React:
- match the repo stack; do not invent a new one
- use the project's formatter/linter
- follow existing React patterns; do not add useMemo/useCallback by default unless the repo does

Terraform:
- in module/sandbox repos you maintain: terraform fmt + validate before done; never apply unless I ask; never print or commit state/secrets
- for Nuon app-config work, follow nuon-app-AGENTS.md (write .tf OK; do not run terraform/helm/cloud CLIs unless approved)

Bash:
- #!/usr/bin/env bash and set -euo pipefail
- shellcheck; quote expansions; prefer explicit over clever

Nuon:
- control-plane ops: prefer Nuon MCP when available; do not parse MCP dumps with python/jq — use narrower MCP tools
- local app-config validate: use the Nuon CLI binary that started the MCP (same -C); say so if falling back to CLI for anything else
- Nuon app-config create/edit/safety rules: read nuon-app-AGENTS.md (no create/delete apps or orgs unless asked)

Output
Plain, concise, active voice. Prefer short dense paragraphs or hyphen bullets. No emoji bullets. No preamble or closing fluff. Fenced code and plan structure are fine in coding chats. Strict no-markdown paste rules live in revenue-AGENTS.md for CRM copy-paste.
