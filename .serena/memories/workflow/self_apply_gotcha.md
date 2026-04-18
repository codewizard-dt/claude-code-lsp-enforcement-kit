# CRITICAL: This Repo's Hooks Apply To Claude Working On It

## The self-referential trap
When Claude works inside `/Users/davidtaylor/Repositories/claude-code-lsp-enforcement-kit`, the **installed hooks in `~/.claude/hooks/`** fire on Claude's own tool calls. The hooks this repo ships are the hooks that constrain Claude here. Expect:

- `Read` on any code file (`.js` under `hooks/`) → **Gate 1 blocks** with warmup demand on first call of session.
- `Grep` for a symbol name (e.g. `buildFileWarmupCall`) → **blocked** by `lsp-first-guard.js`.
- `Glob` with PascalCase/camelCase token (e.g. `*Guard*`) → **blocked** by `lsp-first-glob-guard.js`.
- `Bash(grep …)` with a code symbol → **blocked** by `bash-grep-block.js`.
- `Agent` delegation without `## LSP CONTEXT` block → **may be blocked** depending on tier.

## How to work anyway
- **Warm up early**: call `mcp__serena__get_symbols_overview("<any code file>")` as the first code-exploration action in a session. This primes LSP state so subsequent Reads are gated normally (not blocked on Gate 1). `get_diagnostics` is the cclsp-canonical warmup; Serena's `get_symbols_overview` works equivalently and is the right choice here since cclsp tools aren't available in this agent's session.
- **Use Serena throughout**: `find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern` — these are the user's MANDATORY exploration tools per `.docs/guides/mcp-tools.md` AND they satisfy the kit's own LSP gate.
- **Read markdown/config freely**: `.md .json .yaml .env` etc. are exempt from the Read gate. Use `Read` tool directly.
- **Don't try to Grep for function names**: the hook blocks it. Use `find_symbol` or `find_workspace_symbols` instead.

## When iterating on hooks themselves
- Changes to `hooks/*.js` don't auto-reload — they're installed copies at `~/.claude/hooks/*.js`. To test a local change in Claude Code, re-run `bash install.sh` to re-copy.
- For pure logic validation without reinstall: `echo '<input-json>' | node hooks/<hook>.js` — reads from stdin so you can test in-place.

## Why this matters
If you ignore this and try to Grep/Glob through the codebase, you'll hit a cascade of block messages and waste time. The hooks are working as designed — route around them by using LSP tools from the start.
