# Repository Structure

```
claude-code-lsp-enforcement-kit/
├── README.md                     # Main doc — hero, architecture, per-hook explainers, install
├── CHANGELOG.md                  # Keep-a-Changelog format, SemVer
├── SECURITY.md                   # Responsible disclosure
├── LICENSE                       # MIT
├── install.sh                    # Bash installer (macOS/Linux) — idempotent settings.json merge
├── install.ps1                   # PowerShell installer (Windows)
│
├── hooks/                        # All hook JS — what gets copied to ~/.claude/hooks/
│   ├── lsp-first-guard.js        # #1 Grep blocker
│   ├── lsp-first-glob-guard.js   # #2 Glob blocker
│   ├── bash-grep-block.js        # #3 Shell grep/rg blocker
│   ├── lsp-first-read-guard.js   # #4 Progressive Read gate (the complex one)
│   ├── lsp-pre-delegation.js     # #5 Agent delegation gate
│   ├── lsp-session-reset.js      # #6 SessionStart state wiper
│   ├── lsp-usage-tracker.js      # #7 PostToolUse state writer
│   └── lib/
│       └── detect-lsp-provider.js  # Shared provider detection + suggestion builder
│
├── rules/
│   └── lsp-first.md              # Copied to ~/.claude/rules/, read by Claude on session start
│
├── scripts/
│   └── lsp-status.sh             # Health check — hook count, settings registration, state summary
│
├── assets/
│   └── token-savings.png         # Hero image (1000×988, ~50 KB, 64-color) for README
│
├── .docs/                        # Project docs + task/UAT system
│   ├── guides/
│   │   ├── mcp-tools.md          # MANDATORY MCP tool usage rules — read first on every session
│   │   └── task-lifecycle.md     # How tasks flow: active/ → completed/, pending UAT/ → completed
│   ├── tasks/{active,completed,trashed}/.gitkeep  # Empty dirs + active/README.md spec
│   └── uat/{pending,completed,skipped,trashed,screenshots}/.gitkeep
│
└── .claude/
    ├── commands/                 # Project-local slash commands (see workflow/slash_commands memory)
    └── settings.local.json       # Local permission allowlist (not checked in as source)
```

## Notable
- `.docs/tasks/active/` and `.docs/uat/*` are empty skeletons (`.gitkeep` only) — the task/UAT system is infrastructure, not actively used for dev work yet.
- No `package.json`, no `node_modules/` — the hooks are zero-dep plain Node (require only `fs`, `path`, `os`, `crypto`). They stdin-read JSON, process, stdout-write JSON decisions.
- No test suite, no linter config. Verification is manual via `scripts/lsp-status.sh` + runtime behavior.
