# 002 — Populate `serena-tool-map.yaml`

## Objective

Fill the empty `serena-tool-map.yaml` with a comprehensive entry for every upstream Serena MCP tool, mapping each to the Claude Code tool(s) it replaces and identifying which repo hook (if any) enforces the substitution.

## Approach

Use the upstream Serena tool list (https://oraios.github.io/serena/01-about/035_tools.html, captured in Serena memory `tech/serena_tools_reference`) as the canonical set. For each tool, record category, Serena enablement status, Claude-Code tools it can replace with use-cases, and the enforcing hook filename derived from actual matchers in `hooks/serena-*.js`. Doc-only artifact; no validator script.

## Prerequisites

- [x] Task 001 completed (hooks renamed to `serena-*`, matchers updated to `mcp__serena__*`)
- [x] Serena memory `tech/serena_tools_reference` exists (created 2026-04-18) and reflects current upstream tool list

---

## Steps

### 1. Inventory hook → Claude-tool matchers  <!-- agent: Explore -->

- [x] Read each hook to extract the exact Claude Code tool names it matches and the block/suggest messaging it emits:
  - `hooks/serena-first-guard.js` — identify which tool(s) it guards (expected: code-targeted `Read`/`Edit`/`Write` on source files, or `Task` pre-delegation; confirm from the file)
  - `hooks/serena-first-read-guard.js` — expected: `Read` on code files
  - `hooks/serena-first-glob-guard.js` — expected: `Glob`
  - `hooks/serena-bash-grep-block.js` — expected: `Bash` with grep/rg/ag/find/ls/cat/head/tail/sed/awk patterns
  - `hooks/serena-pre-delegation.js` — expected: `Task`
  - `hooks/serena-session-reset.js` — SessionStart event, not a tool matcher (note this)
  - `hooks/serena-usage-tracker.js` — PostToolUse matcher on `mcp__serena__*` (tracker, not enforcer — note this)
- [x] Produce a short inline notes block (keep as a scratch comment in step 2's YAML draft) capturing: for each hook, { matched Claude tool(s), Serena tools it recommends instead }.
  - Acceptance: every `serena-*.js` file in `hooks/` is accounted for; no hook omitted.

### 2. Draft YAML header + schema legend  <!-- agent: general-purpose -->

- [x] Overwrite `serena-tool-map.yaml` starting with a metadata header:
  ```yaml
  # Serena tool map — which Serena MCP tools replace which Claude Code built-ins,
  # and which hook in this kit enforces the substitution.
  #
  # Source of truth for the Serena tool catalog:
  #   https://oraios.github.io/serena/01-about/035_tools.html
  # Companion Serena memory: tech/serena_tools_reference
  metadata:
    version: 1
    last_updated: 2026-04-18
    serena_source: https://oraios.github.io/serena/01-about/035_tools.html
  ```
- [x] Add a `hooks` legend section listing every hook file with a one-line description of what it blocks/suggests:
  ```yaml
  hooks:
    serena-first-guard.js: "<blocks X, suggests Y>"
    serena-first-read-guard.js: "..."
    serena-first-glob-guard.js: "..."
    serena-bash-grep-block.js: "..."
    serena-pre-delegation.js: "..."
    serena-session-reset.js: "SessionStart — primes Serena tool usage context (no per-tool enforcement)"
    serena-usage-tracker.js: "PostToolUse — tracks mcp__serena__* usage (observability, not enforcement)"
  ```
  - Descriptions must match behaviour observed in step 1, not assumptions.
- [x] Add the top-level `tools:` key under which every tool entry will live.

### 3. Populate symbol-group tools  <!-- agent: general-purpose -->

- [x] Under `tools:`, add one entry per Serena symbol tool using the schema:
  ```yaml
  - tool: find_symbol
    category: symbol
    serena_status: enabled      # enabled | optional | jetbrains-only
    claude_tools_replaced:
      - tool: Grep
        use_case: searching for function/class/method definitions by name
      - tool: Bash
        use_case: grep/rg/ag invocations that look up symbol definitions
    enforcing_hook: serena-first-guard.js
    notes: Prefer name-path patterns (Class/method, /absolute/path) over substring search.
  ```
- [x] Tools to include (all upstream symbol_tools):
  - `find_symbol` (enabled)
  - `find_referencing_symbols` (enabled)
  - `get_symbols_overview` (enabled)
  - `insert_after_symbol` (enabled)
  - `insert_before_symbol` (enabled)
  - `rename_symbol` (enabled)
  - `replace_symbol_body` (enabled)
  - `restart_language_server` (optional)
  - `safe_delete_symbol` (enabled)
- [x] For tools with no direct Claude-Code equivalent (e.g. `restart_language_server`, `rename_symbol`), set `claude_tools_replaced: []` and explain in `notes`.
- [x] `enforcing_hook` values must be actual hook filenames from `hooks/` or `null` when no hook enforces substitution.
  - Acceptance: every symbol tool has a YAML entry; every `enforcing_hook` is `null` or a file that exists in `hooks/`.

### 4. Populate file-group tools  <!-- agent: general-purpose -->

- [x] Add entries for every `file_tools` item:
  - `read_file` (enabled) — replaces Claude `Read` on code files; hook: `serena-first-read-guard.js` (note: this kit prefers native `Read` for markdown/config per `.docs/guides/mcp-tools.md`; document that nuance in `notes`)
  - `create_text_file` (enabled) — replaces `Write` for new code files; `enforcing_hook: null` (no hook blocks `Write`)
  - `list_dir` (enabled) — replaces `Bash ls`/`Bash find -type d`; hook: `serena-bash-grep-block.js` (and `Glob` via `serena-first-glob-guard.js`)
  - `find_file` (enabled) — replaces `Glob` / `Bash find -name`; hook: `serena-first-glob-guard.js` + `serena-bash-grep-block.js`
  - `search_for_pattern` (enabled) — replaces `Grep` on code / `Bash grep|rg|ag`; hook: `serena-bash-grep-block.js` (+ `serena-first-guard.js` where applicable)
  - `replace_content` (enabled) — replaces `Edit` / `Bash sed|awk` on code files; hook: `null` (policy-only via `.docs/guides/mcp-tools.md`); document the policy in `notes`
  - `replace_lines` (optional) — replaces line-range edits via `Bash sed -i`; enforcing_hook: `null`
  - `insert_at_line` (optional) — replaces `Bash sed`/`echo >>`; enforcing_hook: `null`
  - `delete_lines` (optional) — replaces `Bash sed`; enforcing_hook: `null`
- [x] For each entry explicitly cite the anti-pattern from `.docs/guides/mcp-tools.md` that the tool addresses when relevant (e.g., "`sed` to flip task-file checkboxes" → `replace_content` in literal mode).
  - Acceptance: all 9 file_tools entries present; `serena_status` correctly flags `optional` where upstream says so.

### 5. Populate memory, workflow, config, shell, query, and jetbrains tools  <!-- agent: general-purpose -->

- [x] Memory group (all enabled upstream, all enabled here): `list_memories`, `read_memory`, `write_memory`, `edit_memory`, `rename_memory`, `delete_memory` — `claude_tools_replaced: []` (no Claude built-in equivalent); `enforcing_hook: null`; `notes` explains when to prefer each.
- [x] Workflow group (all enabled): `initial_instructions`, `check_onboarding_performed`, `onboarding` — `claude_tools_replaced: []`; `enforcing_hook: serena-session-reset.js` where the session-reset hook references onboarding/check, else `null`.
- [x] Config group: `activate_project`, `get_current_config` (both enabled upstream; not available in this Claude Code session — mark `serena_status: enabled` but note availability in `notes`); `open_dashboard`, `remove_project` (both optional). `claude_tools_replaced: []`; `enforcing_hook: null`.
- [x] Shell group: `execute_shell_command` — replaces Claude `Bash`; `serena_status: enabled`; `enforcing_hook: null` (this kit uses native `Bash`, not Serena's — note the rationale).
- [x] Query-project group (both optional): `list_queryable_projects`, `query_project` — `claude_tools_replaced: []`; `enforcing_hook: null`; `notes` explains cross-project RAG use case.
- [x] JetBrains group (all optional, IDE-only, `serena_status: jetbrains-only`): `jet_brains_find_symbol`, `jet_brains_find_declaration`, `jet_brains_find_implementations`, `jet_brains_find_referencing_symbols`, `jet_brains_get_symbols_overview`, `jet_brains_rename`, `jet_brains_move`, `jet_brains_inline_symbol`, `jet_brains_safe_delete`, `jet_brains_type_hierarchy`. `claude_tools_replaced: []`; `enforcing_hook: null`; `notes: "Alternative backend when Serena is paired with a JetBrains IDE; not relevant in Claude Code."`.
  - Acceptance: grand total of tool entries matches the upstream catalog (~40). Each group is complete.

### 6. Verification  <!-- agent: general-purpose -->

- [x] YAML parses cleanly: `node -e "console.log(require('js-yaml').load(require('fs').readFileSync('serena-tool-map.yaml','utf8')).tools.length)"` (or `python3 -c "import yaml; print(len(yaml.safe_load(open('serena-tool-map.yaml'))['tools']))"`). Expected: roughly 40.
- [x] Every `enforcing_hook` value is either `null` or an existing file under `hooks/` (enumerate with `mcp__serena__list_dir` or `Glob`).
- [x] No duplicate `tool:` names (one-liner: `grep -c '^  - tool:' serena-tool-map.yaml` matches the reported length).
- [x] Spot-check the five tools most central to this kit (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`, `find_file`) — each has a non-empty `claude_tools_replaced` list and a real hook filename.
- [x] Cross-reference with `tech/serena_tools_reference` memory: every tool listed there appears in the YAML; if any new tools appeared upstream since 2026-04-18, note them in the memory as well.
- [x] Commit message drafted: `docs: populate serena-tool-map.yaml with upstream tool catalog and hook mapping`. <!-- Completed: 2026-04-18 -->

---
**UAT**: [`.docs/uat/skipped/002-serena-tool-map.uat.md`](../../uat/skipped/002-serena-tool-map.uat.md) *(skipped)*
