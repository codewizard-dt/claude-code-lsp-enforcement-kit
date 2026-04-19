# Tech Stack

## Core runtime
- **Node.js** (plain, no package.json, no dependencies). All hooks are self-contained scripts requiring only built-ins: `fs`, `path`, `os`, `crypto`.
- **Bash** for `install.sh` and `scripts/lsp-status.sh`.
- **PowerShell** for `install.ps1` (Windows parity).

## No build chain
- No TypeScript, no transpilation. The "TypeScript-LSP" in the name refers to what the hooks *enforce* LSP usage *for*, not how the hooks are written.
- No test runner, no linter, no formatter. Code is hand-maintained JS.
- No CI workflows in the repo (no `.github/` at time of writing).

## Target integration
- **Claude Code** (CLI, Desktop, IDE extensions). Uses Claude Code's hook system: `PreToolUse`, `PostToolUse`, `SessionStart` events with matchers.
- **LSP MCP provider**: **Serena** (multi-language, by Oraios AI — MIT). Single provider as of v3.0. Shared helper: `hooks/lib/serena.js`. Block-message copy and PostToolUse tracker both reference `mcp__serena__*` exclusively; cclsp and the bundled `typescript-lsp` plugin were removed.

## Hook contract
Each hook reads stdin (tool input JSON from Claude Code), processes, exits with:
- `exit 0` + stdout JSON `{decision, reason, ...structured}` → blocks or warns
- `exit 0` no output → allows
- `exit 1` → **passthrough** (Claude Code treats crash as allow; security-critical — see `project/security_principles` memory)
