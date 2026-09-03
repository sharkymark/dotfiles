Workflow Orchestration

1. Plan Mode Default

Enter plan mode for architectural, multi-file, or hard-to-reverse changes; skip it for small, single-file, or obvious edits
If something goes sideways, STOP and re-plan immediately – don't keep pushing
Use plan mode for verification steps too, not just building
Write detailed specs upfront to reduce ambiguity

2. Subagent Strategy

Use subagents liberally to keep main context window clean
Offload research, exploration, and parallel analysis to subagents
For complex problems, throw more compute at it via subagents
One tack per subagent for focused execution

3. Self-Improvement Loop

After ANY correction from the user: save the lesson to persistent project memory (a memory file plus its MEMORY.md index line) so it auto-loads next session
Do not rely on tasks/lessons.md for this — it is not auto-read into context, so lessons written there are forgotten
Write rules for yourself that prevent the same mistake and iterate until the mistake rate drops

4. Verification Before Done

For small, single-file, or obvious edits: run the relevant test/build/lint and call it done
For multi-file, architectural, or behavior-changing work: also diff behavior between main and the change, and demonstrate correctness with logs or a test run before marking complete
Never mark a task complete without proving it works

5. Demand Elegance (Balanced)

Skip this for simple, obvious fixes – don't over-engineer
For non-trivial changes: pause and ask "is there a more elegant way?" before presenting it
If a fix feels hacky, say so and implement the elegant solution instead

6. Autonomous Bug Fixing

When given a bug report: just fix it. Don't ask for hand-holding
Point at logs, errors, failing tests – then resolve them
Zero context switching required from the user
Go fix failing CI tests without being told how

7. Model Tiering

Use the strongest model your session is configured to use for planning and hard or ambiguous reasoning; switch to a cheaper, faster model to execute a well-specified plan. Do not escalate to a pricier tier than the session is set to
When spawning subagents, route mechanical execution work (edits, running tests, applying a plan) to a cheaper model and reserve the configured planning model for planning and ambiguous reasoning
This only holds when the plan is detailed (see Plan Mode Default); a vague plan hands the cheaper model too much room
Section 7 applies to Claude Code, Gemini CLI, Goose, and other non-Cursor tools. In Cursor, see the Cursor section below instead of manually picking models for the parent agent


Cursor

For Cursor IDE and CLI sessions, use Auto (Cursor Router) as the default model selection. Do not manually pick Composer, Grok, or Claude unless the user explicitly requests a specific model

Default for all work: Auto with Cost optimization. Cost routing prefers Composer 2.5 and Cursor Grok, which draw from the Cursor Models pool and are exempt from the Cursor Token Rate that third-party models incur on Teams plans

Do not use Auto with Balance or Auto with Intelligence by default. Both route freely to third-party models (Claude, GPT, Gemini), which draw from the smaller Other Models pool and bill at provider list price plus $0.25 per million tokens. Escalate to Balance or Intelligence only for a specific hard task, and drop back to Cost afterward

Architectural or ambiguous work: switch to Plan mode before implementing; do not rely on Auto routing alone for the planning phase
If the user pins a model (e.g. Opus 5), use that model for the session

Explore and other mechanical subagents use Composer 2.5 via cursor/cli-config.json subagentModels; do not override unless the user asks
Do not pin Claude, Opus, or Composer for the parent session unless Mark asks

Do not pin Composer 2.5 as the parent-session model. It is a coding-optimized model and is the wrong fit for research, CRM, and meeting-summary work; let Auto Cost pick between Composer and Grok instead

For research, CRM writes, and meeting analysis, Auto Cost should prefer Cursor Grok over Composer when the router has a choice

Turn off Cursor commit and PR attribution in Cursor Settings > Agents > Attribution (or Git & PRs > Attribution). Keep attributeCommitsToAgent and attributePRsToAgent false in ~/.cursor/cli-config.json


Task Management

Plan First: Write plan to tasks/todo.md with checkable items
Verify Plan: Check in before starting implementation
Track Progress: Mark items complete as you go
Explain Changes: High-level summary at each step
Document Results: Add review section to tasks/todo.md
Capture Lessons: Save corrections to persistent project memory, not tasks/lessons.md


Core Principles

Simplicity First: Make every change as simple as possible. Impact minimal code.
No Laziness: Find root causes. No temporary fixes. Senior developer standards.
Minimal Impact: Changes should only touch what's necessary. Avoid introducing bugs.


Language and Tooling Defaults

These apply when a repo has no CLAUDE.md/AGENTS.md of its own. A repo-level file always overrides this section.

Git and commits:
- do not commit or push unless I ask; if on a default branch, branch first
- prefer small, focused commits over large mixed ones
- never add Co-authored-by, Made-with, or any AI, agent, or bot attribution to commit messages, PR titles, or PR bodies
- never set git author or committer to an agent or bot identity (e.g. cursoragent@cursor.com); commits must use the human user only
- do not install git hooks to strip or rewrite attribution; fix attribution at the source (agent behavior and Cursor settings) instead
- if attribution was already pushed, rewrite commit messages to remove it and force-push only on feature branches the user owns, using --force-with-lease

Go:
- format with gofmt (or goimports); run go vet before considering work done
- test with go test ./... ; run a single package with go test ./path/to/pkg and a single test with go test -run TestName ./path/to/pkg
- build with go build ./... ; keep the module path in go.mod correct
- handle every error explicitly; do not swallow errors or use panic for control flow

Python:
- prefer uv for envs and installs (uv venv, uv pip install); fall back to the repo's venv/ and requirements.txt if that is the pattern
- format and lint with ruff (ruff format, ruff check); test with pytest
- run scripts inside the repo's venv, not system Python

Terraform:
- run terraform fmt and terraform validate before done
- NEVER run terraform apply automatically; show the plan and let me apply
- treat state as sensitive; never print or commit state or secrets

Bash:
- start scripts with #!/usr/bin/env bash and set -euo pipefail
- check with shellcheck; quote variable expansions; prefer explicit over clever

Output Formatting

- no emojis or special characters used as bullets or decorators
- no indentation
- no extra blank lines between items
- use plain hyphens (-) for bullet lists only, no other list markers
- write in clean, dense paragraphs or flat hyphen-bulleted lists
- do not use markdown headers, bold, italics, or any other markdown formatting
- do not add any preamble, closing remarks, or meta-commentary about the output
- no em dashes
- write in plain, concise language at an 8th-grade reading level; keep responses short, use active voice, and strictly avoid fancy vocabulary, AI clichés, corporate jargon, or robotic fluff.
