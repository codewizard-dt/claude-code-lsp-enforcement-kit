# Hook Architecture — 6 Blockers + 1 Tracker + 1 Session Reset

## Hook registry

| # | File | Hook type | Matcher | Role |
|---|------|-----------|---------|------|
| 1 | `lsp-first-guard.js` | PreToolUse | `Grep` | Blocks Grep on code symbols (camelCase/PascalCase/dotted/snake_case) |
| 2 | `lsp-first-glob-guard.js` | PreToolUse | `Glob` | Blocks `*SymbolName*`-style glob patterns (symbol-by-filename bypass) |
| 3 | `bash-grep-block.js` | PreToolUse | `Bash` | Blocks `grep`/`rg`/`ag`/`ack` in shell when pattern is a code symbol |
| 4 | `lsp-first-read-guard.js` | PreToolUse | `Read` | 5-gate progressive Read gate (warmup → free → warn → nav → surgical) |
| 5 | `lsp-pre-delegation.js` | PreToolUse | `Agent` | Blocks sub-agent delegation without pre-resolved LSP context (subagents can't access MCP) |
| 6 | `lsp-session-reset.js` | SessionStart | `true` | Wipes stale `nav_count` so new sessions re-trigger Gate 1 warmup |
| 7 | `lsp-usage-tracker.js` | PostToolUse | all `mcp__cclsp__*` / Serena LSP tool names | Writes state file other hooks read |

## State file
`~/.claude/state/lsp-ready-<md5(cwd)>` — JSON with `{warmup_done, nav_count, read_count, read_files[], timestamp, last_tool}`. 24h expiry (stale-proofed by hook 6).

## Gate thresholds (hook 4 — Read guard)
```
Gate 1  (no state file)         → BLOCK, require LSP warmup (any get_diagnostics or get_symbols_overview)
Gate 2  (reads 1–2)             → ALLOW freely
Gate 3  (read 3, nav_count=0)   → WARN "next Read will be blocked"
Gate 4  (reads 4–5)             → BLOCK unless nav_count ≥ 1
Gate 5  (reads 6+)              → BLOCK unless nav_count ≥ 2, then SURGICAL MODE (unlimited)
```

## Always-exempt from Read gate
Non-code extensions (`.md .json .yaml .env .sql .css .html`), framework configs (`tsconfig.json`, `next.config.ts`, `package.json`), test files (`*.test.ts`, `*.spec.tsx`), non-code paths (`.task/`, `.claude/`, `node_modules/`, `__tests__/`). Dedup: same file at different line ranges counts once.

## Agent delegation tiers (hook 5)
- **Force-enforce**: `frontend-explorer`, `backend-explorer`, `db-explorer` — always BLOCK without `## LSP CONTEXT` block in prompt
- **Standard**: implementation agents, worktree-isolated agents — BLOCK during implement phase
- **Exempt**: reviewers, testers, planners, auditors — never enforced (read-only)

## Shared lib exports (`hooks/lib/detect-lsp-provider.js`)
Top-level functions: `detectProviders`, `isLspProviderTool`, `getTrackerToolNameRegex`, `buildSuggestion`, `buildStructuredSuggestions`, `buildStructuredBlockResponse`, `buildWarmupInstructions`, `buildFileWarmupCall`, `hasBundledTypescriptLspPlugin`, `collectMcpServerNames`, `readJsonSilent`.
