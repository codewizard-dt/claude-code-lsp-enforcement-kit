# 001 — Refactor hooks to Serena-only

## Objective

Strip cclsp and provider-detection from the LSP enforcement kit so every hook, installer, rule, and doc references Serena exclusively, and rename all hook files from `lsp-*` to `serena-*` with installer cleanup of old filenames.

## Approach

Collapse the multi-provider registry in `hooks/lib/detect-lsp-provider.js` into a single-provider Serena module (renamed `hooks/lib/serena.js`). Rename every hook file to `serena-*`, update installers to register the new filenames with `mcp__serena__*` matchers and unlink the old ones, and drop the `typescript-lsp` plugin enablement. Bump to v3.0 (breaking).

## Prerequisites

- [ ] Project has working Serena MCP server configured (`mcp__serena__*` tools available)
- [ ] Clean git worktree before starting (tracked changes committed)

---

## Steps

### 1. Rename + simplify shared library  <!-- agent: general-purpose --> <!-- Completed: 2026-04-18 -->

- [x] Rename `hooks/lib/detect-lsp-provider.js` → `hooks/lib/serena.js` (use `git mv` to preserve history)
- [x] Rewrite the module as a single-provider Serena helper:
  - Remove the `PROVIDERS` registry object entirely; inline Serena constants
  - Remove `cclsp` entry and all branching that iterates providers
  - Remove `hasBundledTypescriptLspPlugin()` and any `~/.claude.json` / settings scanning for plugin detection
  - Remove `collectMcpServerNames()` multi-provider logic; if a Serena-presence check is still desired, keep a minimal `hasSerena()` that scans `~/.claude.json` mcpServers for a `serena` key
  - Simplify `buildSuggestion()`, `buildStructuredSuggestions()`, `buildStructuredBlockResponse()`, `buildFileWarmupCall()`, `buildWarmupInstructions()` to emit Serena-only strings (no provider loops, no labels like `(Serena)` since there is only one)
  - Replace `isLspProviderTool(toolName)` and `getTrackerToolNameRegex()` with Serena-specific versions: match `mcp__serena__*` and `mcp__plugin_*serena*__*` only
  - Export constants: `SERENA_PREFIX = 'mcp__serena__'`, `WARMUP_TOOL = 'get_symbols_overview'`, plus the helper fns
- [x] Update all block-message copy to reference Serena tools by their actual names:
  - definition/symbol_search → `find_symbol`
  - references/incoming_calls → `find_referencing_symbols`
  - overview/warmup → `get_symbols_overview`
  - Remove references to `find_definition`, `find_references`, `find_workspace_symbols`, `find_implementation`, `get_hover`, `get_diagnostics`, `get_incoming_calls`, `get_outgoing_calls` (these are cclsp names)
  - Acceptance: grep/search for `cclsp` across `hooks/lib/serena.js` returns zero matches

### 2. Rename and update all hook files  <!-- agent: general-purpose --> <!-- Completed: 2026-04-18 -->

- [x] Rename each hook file (use `git mv` for each):
  - `hooks/lsp-first-guard.js` → `hooks/serena-first-guard.js`
  - `hooks/lsp-first-glob-guard.js` → `hooks/serena-first-glob-guard.js`
  - `hooks/lsp-first-read-guard.js` → `hooks/serena-first-read-guard.js`
  - `hooks/lsp-pre-delegation.js` → `hooks/serena-pre-delegation.js`
  - `hooks/lsp-session-reset.js` → `hooks/serena-session-reset.js`
  - `hooks/lsp-usage-tracker.js` → `hooks/serena-usage-tracker.js`
  - `hooks/bash-grep-block.js` → `hooks/serena-bash-grep-block.js` (optional but aligns naming; keep `bash-grep-block.js` if simpler)
- [x] Update `require()` paths in each renamed hook to point at `./lib/serena` instead of `./lib/detect-lsp-provider`
- [x] Update `serena-usage-tracker.js`:
  - Use new `isLspProviderTool`/`getTrackerToolNameRegex` from `lib/serena.js` (Serena-only)
  - Cold-start error detection: replace the cclsp "No Project" error heuristic with a Serena-equivalent check, or remove it if Serena has no analogous error
- [x] Update `serena-first-read-guard.js`:
  - `buildConcreteCall()` and warmup messaging must use `mcp__serena__get_symbols_overview` instead of `mcp__cclsp__get_diagnostics`
  - Block messages reference Serena tools only (no multi-provider iteration)
- [x] Update `serena-first-guard.js`, `serena-first-glob-guard.js`, `serena-pre-delegation.js`, `bash-grep-block.js`:
  - All block messages emit Serena tool suggestions only
  - Remove any `cclsp` / `plugin_cclsp` conditionals
- [x] Verification: `grep -r cclsp hooks/` returns zero matches (via `mcp__serena__search_for_pattern`)

### 3. Update install scripts with old-file cleanup  <!-- agent: general-purpose --> <!-- Completed: 2026-04-18 -->

- [x] Update `install.sh`:
  - Copy the new `serena-*.js` hooks + `lib/serena.js` to `~/.claude/hooks/`
  - **Unlink old hook files** if they exist at `~/.claude/hooks/lsp-first-guard.js`, `lsp-first-glob-guard.js`, `lsp-first-read-guard.js`, `lsp-pre-delegation.js`, `lsp-session-reset.js`, `lsp-usage-tracker.js`, and `lib/detect-lsp-provider.js`
  - Update `settings.json` merge logic:
    - PreToolUse hook commands point at `serena-*.js` filenames
    - PostToolUse tracker matcher: change `mcp__cclsp__find_definition|...|mcp__cclsp__get_outgoing_calls` → `mcp__serena__find_symbol|mcp__serena__find_referencing_symbols|mcp__serena__get_symbols_overview|mcp__serena__find_file|mcp__serena__search_for_pattern|mcp__serena__list_dir` (or a broader `mcp__serena__.*` regex if the settings format allows)
    - **Remove** any old hook entries (commands ending in `lsp-first-*.js` / `lsp-pre-delegation.js` / `lsp-session-reset.js` / `lsp-usage-tracker.js`) from existing PreToolUse/PostToolUse/SessionStart arrays during merge
  - **Remove** `typescript-lsp@claude-plugins-official` from `enabledPlugins` (no longer needed)
  - Update installer banner: `[2/4] Copied 7 hooks + lib` → reflect actual count, and the "Plugin enabled" verification line becomes "Serena provider detected" (or remove it)
- [x] Apply the same changes to `install.ps1` (PowerShell equivalent, same cleanup + rename logic)
- [x] Both installers must remain idempotent: re-running after manual settings edits must not duplicate entries

### 4. Update rules + status script  <!-- agent: general-purpose --> <!-- Completed: 2026-04-18 -->

- [x] Rewrite `rules/lsp-first.md` to reference Serena tools only:
  - Table columns map tasks → Serena tool (e.g., Definition → `find_symbol`, References → `find_referencing_symbols`, Overview → `get_symbols_overview`)
  - Remove any cclsp tool names
  - Update title/heading if it currently mentions "LSP-First" — keep "LSP-First" (Serena is an LSP provider) OR rename to "Serena-First" (pick one; document the choice in the rule file header)
- [x] Update `scripts/lsp-status.sh`:
  - "Hook files" check counts `serena-*.js` filenames
  - "Detected providers" check verifies Serena only (exits cleanly if Serena is installed, warns otherwise)
  - "Plugin enabled" check removed
  - PostToolUse matcher validation checks for `mcp__serena__` in the settings file, not `mcp__cclsp__`

### 5. Update README + CHANGELOG  <!-- agent: general-purpose --> <!-- Completed: 2026-04-18 -->

- [x] Rewrite `README.md`:
  - Remove "Works with any LSP MCP server" section and all provider-detection copy
  - All example block messages reference `mcp__serena__*` tools
  - "Architecture" diagram updated with `serena-*` hook filenames
  - "How Each Hook Works" section — each subheading uses new filename
  - Update "Optional: Python, Go, Rust Support" section: remove cclsp config; point users at Serena's built-in `solidlsp` multi-language support instead
  - FAQ: remove "Does this work with Serena?" and "What about Python/Go/Rust? cclsp is TypeScript-only" questions; replace with Serena-centric wording
  - Manual setup section: update PreToolUse/PostToolUse snippets with new filenames and `mcp__serena__*` matcher
  - Bump version badge if present
- [x] Add `CHANGELOG.md` entry for **v3.0.0** (breaking):
  - "Breaking: removed cclsp provider support. Kit is now Serena-only."
  - "Breaking: all hooks renamed `lsp-*` → `serena-*`. Installer auto-cleans old files; manual settings.json installs require updating hook command paths."
  - "Breaking: PostToolUse tracker matcher changed from `mcp__cclsp__*` to `mcp__serena__*`."
  - "Removed: `typescript-lsp` plugin enablement from installer."
  - "Migration: re-run `bash install.sh` (or `pwsh ./install.ps1`) to apply."

### 6. Verification  <!-- agent: general-purpose --> <!-- Completed: 2026-04-18 -->

- [x] `mcp__serena__search_for_pattern` for `cclsp` across the repo (excluding `.git/`, `CHANGELOG.md`, and `.serena/`) returns zero matches
- [x] `mcp__serena__search_for_pattern` for `lsp-first-|lsp-pre-delegation|lsp-usage-tracker|lsp-session-reset|detect-lsp-provider` across the repo returns zero matches (these are the old filenames)
- [x] Run `node hooks/serena-first-guard.js < /dev/null` (or equivalent syntax check for each hook) — each hook loads without throwing
- [x] Run `bash install.sh` in a throwaway HOME (`HOME=/tmp/fake-home bash install.sh`) to verify:
  - 7 hooks + lib copied
  - settings.json created with `serena-*` commands and `mcp__serena__*` matcher
  - `typescript-lsp` plugin NOT enabled
- [x] Run `bash scripts/lsp-status.sh` — all checks pass, no mentions of cclsp in output
- [x] Commit message drafted: `feat!: v3.0 — Serena-only hooks, rename lsp-* → serena-*`

---

**UAT**: [`.docs/uat/skipped/001-serena-only-hooks.uat.md`](../../uat/skipped/001-serena-only-hooks.uat.md) *(skipped)*
