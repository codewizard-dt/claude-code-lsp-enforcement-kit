# Code Style & Conventions

## JavaScript (hooks)
- **Plain Node.js ES syntax** (`require`, `module.exports`) — no ESM, no TypeScript.
- **Zero dependencies** — only Node built-ins.
- **File-level constants in SCREAMING_SNAKE_CASE**: `STATE_DIR`, `FREE_READS`, `WARN_AT`, `CODE_EXTENSIONS`, `ALLOW_CONFIG_PATTERNS`.
- **Functions in camelCase**: `buildFileWarmupCall`, `detectProviders`, `readFlag`, `emitBlock`.
- **Regex constants suffixed `_RE`**: `PLUGIN_WRAPPED_RE`.
- **No classes** — functional modules, small top-level functions.
- **Short files** — most hooks ~100–300 LOC. The Read guard is the largest (it's the gate state machine).
- **Entry pattern**: `process.stdin.on('data', …)` + `process.stdin.on('end', …)` callbacks; parse input JSON, decide, `console.log(JSON.stringify({decision, reason, ...}))`, exit 0.
- **Safety coercion**: always `String(x ?? '').trim()` before string ops on tool inputs — a historical fail-open bug (v2.1 security audit) was type-confusion crashes treated as passthrough by Claude Code.

## Block-message strings
- Lead with an emoji marker: `⛔` for BLOCK, `🛡️` for GATE, `⚠️` for WARN.
- Include the **exact copy-pasteable LSP command** (parametrized by the file/symbol at hand — never generic).
- Structured output alongside human-readable: `{hook, symbols, intent, providers, suggestions[]}` for machine consumers; legacy `{decision, reason}` preserved.

## Shell (install.sh, lsp-status.sh)
- `#!/usr/bin/env bash` + `set -euo pipefail`.
- Absolute path resolution via `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"`.
- JSON manipulation delegated to `node -e '…'` (avoid jq/sed fragility).

## Markdown
- Keep-a-Changelog format for `CHANGELOG.md`, SemVer.
- README uses centered HTML hero (`<p align="center">`) + shields.io badges + emoji section markers.
- Tables preferred over bulleted lists for config/rule explanations.

## Naming
- Hooks: `serena-<role>.js` (kebab-case, v3.0). Role suffix: `-guard`, `-block`, `-tracker`, `-reset`, `-pre-delegation`.
- Provider tools referenced by their full MCP name: `mcp__serena__find_symbol`, `mcp__serena__find_referencing_symbols`, `mcp__serena__get_symbols_overview` (Serena-only as of v3.0).
