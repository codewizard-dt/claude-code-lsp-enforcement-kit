# Repository Structure (v3.0)

```
claude-code-lsp-enforcement-kit/
├── README.md                     # Main doc — hero, architecture, per-hook explainers, install
├── CHANGELOG.md                  # Keep-a-Changelog format, SemVer
├── SECURITY.md                   # Responsible disclosure
├── LICENSE                       # MIT
├── install.sh                    # Bash installer (macOS/Linux) — idempotent settings.json merge + old-file cleanup
├── install.ps1                   # PowerShell installer (Windows) — mirrors install.sh
├── serena-tool-map.yaml          # Serena tool ↔ Claude-Code tool mapping (v3, complete — 44 tools across 8 groups)
│
├── hooks/                        # All hook JS — what gets copied to ~/.claude/hooks/
│   ├── serena-first-guard.js        # #1 Grep blocker
│   ├── serena-first-glob-guard.js   # #2 Glob blocker
│   ├── serena-bash-grep-block.js    # #3 Shell grep/rg blocker
│   ├── serena-first-read-guard.js   # #4 Progressive Read gate (the complex one)
│   ├── serena-pre-delegation.js     # #5 Agent delegation gate
│   ├── serena-session-reset.js      # #6 SessionStart state wiper
│   ├── serena-usage-tracker.js      # #7 PostToolUse state writer
│   └── lib/
│       └── serena.js                # Shared Serena helpers (single-provider, v3.0)
│
├── rules/
│   └── lsp-first.md              # Copied to ~/.claude/rules/, read by Claude on session start
│
├── scripts/
│   └── lsp-status.sh             # Health check — hook count, settings registration, state summary (Serena-only)
│
├── assets/
│   └── token-savings.png         # Hero image for README
│
├── .docs/                        # Project docs + task/UAT system
│   ├── guides/
│   │   ├── mcp-tools.md          # MANDATORY MCP tool usage rules — read first on every session
│   │   └── task-lifecycle.md     # How tasks flow: active/ → completed/, pending UAT/ → completed
│   ├── tasks/
│   │   ├── README.md             # Index of active/completed tasks
│   │   ├── active/               # (empty — all tasks complete)
│   │   ├── completed/
│   │   │   ├── 001-serena-only-hooks.md    # v3.0 refactor (UAT skipped)
│   │   │   └── 002-serena-tool-map.md      # serena-tool-map.yaml population (UAT skipped)
│   │   └── trashed/              # (empty)
│   └── uat/
│       ├── pending/
│       ├── completed/
│       ├── skipped/
│       │   ├── 001-serena-only-hooks.uat.md # skip skeleton for v3.0 refactor
│       │   └── 002-serena-tool-map.uat.md   # skip skeleton for tool map task
│       ├── trashed/
│       └── screenshots/
│
└── .claude/
    ├── commands/                 # Project-local slash commands (see workflow/docs_and_slash_commands memory)
    └── settings.local.json       # Local permission allowlist (not checked in as source)
```

## Notable
- Hooks are zero-dep plain Node (require only `fs`, `path`, `os`, `crypto`). They stdin-read JSON, process, stdout-write JSON decisions.
- No `package.json`, no `node_modules/`, no test suite, no linter config. Verification is manual via `scripts/lsp-status.sh` + runtime behavior.
- `.serena/memories/` holds project knowledge; `tech/serena_tools_reference` documents the full upstream Serena tool catalog.
