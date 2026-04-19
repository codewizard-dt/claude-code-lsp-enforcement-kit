# Serena MCP Tools — Complete Reference

Authoritative reference for every tool exposed by the upstream Serena MCP server (`oraios/serena`), regardless of whether it is currently enabled in this project's MCP configuration.

Source of truth: https://oraios.github.io/serena/01-about/035_tools.html

All tools are namespaced `mcp__serena__<tool>` when invoked through Claude Code.

---

## Enablement in this project

This repo connects Serena in the default Claude Code configuration. The tools actually exposed in-session (confirmed via the deferred tool list) are a subset of upstream. "Status" columns below track both upstream defaults and this project's reality.

- **Upstream default**: on/off according to Serena's shipped defaults (from 035_tools.html).
- **Available here**: whether the tool currently appears in this project's MCP deferred-tool list. "No" means Claude Code's built-in tools (Read/Edit/Write/Glob/Grep/Bash) are being used in its place.

Tools flagged *(optional)* upstream are disabled by default and must be enabled in `serena_config.yml` / MCP `args` to appear.

---

## 1. Symbol tools (LSP-backed semantic code ops)

The core value of Serena — semantic navigation and refactoring via a language server, not regex.

| Tool | Upstream default | Available here | Purpose |
|------|------------------|----------------|---------|
| `find_symbol` | on | yes | Global/local search for symbols by `name_path_pattern`. Supports `depth`, `include_body`, `include_info`, `substring_matching`, `include_kinds`/`exclude_kinds` filters. Name paths: `"method"`, `"Class/method"`, `"/Class/method"` (absolute), `"Class/method[0]"` (overload index). |
| `find_referencing_symbols` | on | yes | All callers/references to a symbol. Takes `name_path` + `relative_path` (file, not dir). Returns referencer symbol + short code snippet. |
| `get_symbols_overview` | on | yes | High-level symbol tree of a single file. First call when exploring an unfamiliar file. `depth=0` (top-level) is default. |
| `replace_symbol_body` | on | yes | Replace the full body of a symbol (fn/class/method). Body must include the signature line; must NOT include leading docstrings/comments. |
| `insert_before_symbol` | on | yes | Insert content on the line immediately before a symbol's definition. Primary use: new imports at top of file, new class/fn above another. |
| `insert_after_symbol` | on | yes | Insert content on the line immediately after a symbol's definition ends. Primary use: adding a new method/field/fn alongside an existing one. |
| `rename_symbol` | on | yes | LSP rename across the whole codebase. Safer than find/replace for renames. For overloaded langs (Java) the signature may be required. |
| `safe_delete_symbol` | on | yes | Delete a symbol only if it has no remaining references; otherwise returns the reference list so the agent can clean up first. |
| `restart_language_server` | *(optional)* | no | Restart the LSP backend. Needed after out-of-band file edits (e.g. `git checkout`) desync the server. |

Typical workflow: `get_symbols_overview` → `find_symbol` → edit with `replace_symbol_body` / `insert_*` → verify with `find_referencing_symbols`.

---

## 2. File tools (path/line/pattern ops — compete with Claude Code built-ins)

Upstream ships these, but the Serena team recommends disabling them when running inside a harness that already has Read/Edit/Grep/Glob (Claude Code does). In this repo, Claude Code's native tools are preferred per `.docs/guides/mcp-tools.md` — only symbolic + memory Serena tools are actively used.

| Tool | Upstream default | Available here | Purpose |
|------|------------------|----------------|---------|
| `read_file` | on | no | Read a file from the project. Claude Code's `Read` covers this. |
| `create_text_file` | on | no | Create or overwrite a file. Claude Code's `Write` covers this. |
| `list_dir` | on | no | List directory contents, optionally recursive, honouring `.gitignore`. Claude Code's `Glob` / `Bash ls` cover this. Known bug: passing `relative_path="."` can error on some projects (oraios/serena#672). |
| `find_file` | on | no | Find files by mask in a root path. Overlaps with `Glob`. |
| `search_for_pattern` | on | no | Flexible regex search across the repo with glob filters and context. Overlaps with `Grep`. |
| `replace_content` | on | no | Literal or regex text replacement inside a file. `mode` ∈ {literal, regex}, plus `needle`/`repl`. Overlaps with `Edit`. |
| `replace_lines` | *(optional)* | no | Replace an inclusive line range (0-based) with new content. |
| `insert_at_line` | *(optional)* | no | Insert content at a specific line number (0-based). |
| `delete_lines` | *(optional)* | no | Delete an inclusive line range (0-based). |

When these are disabled, always prefer symbolic tools for code edits; use Claude Code's built-ins for markdown/config.

---

## 3. Memory tools

Persistent project knowledge stored at `.serena/memories/<name>.md`. Use `/` in names for topic hierarchy (e.g. `tech/stack`). Global-scope memories use a `global/` prefix and are shared across all Serena projects (only when explicitly asked).

| Tool | Upstream default | Available here | Purpose |
|------|------------------|----------------|---------|
| `list_memories` | on | yes | List memory names. Optional `topic` filter matches name prefix (`"auth"` → everything under `auth/`). |
| `read_memory` | on | yes | Read a memory by name. Only call when the name suggests relevance to the current task. |
| `write_memory` | on | yes | Create/overwrite a memory. Params: `memory_name`, `content` (markdown), optional `max_chars`. |
| `edit_memory` | on | yes | In-place edit of an existing memory. Params: `needle`, `repl`, `mode` (`literal`/`regex`), `allow_multiple_occurrences`. Prefer over rewriting. |
| `rename_memory` | on | yes | Move or rename a memory (use `/` to re-topic). |
| `delete_memory` | on | yes | Delete a memory. Only call when the user explicitly instructs or grants permission. |

---

## 4. Workflow tools

| Tool | Upstream default | Available here | Purpose |
|------|------------------|----------------|---------|
| `initial_instructions` | on | yes | Returns the "Serena Instructions Manual". Call at the start of a session if the client didn't auto-load MCP instructions. |
| `check_onboarding_performed` | on | yes | Checks if `.serena/memories/` has been initialised for this project. Always call first when activating a project. |
| `onboarding` | on | yes | Runs the onboarding flow: inspect project layout, author starter memories (overview, structure, style, suggested commands, etc.). Call at most once per conversation. |

---

## 5. Config tools

| Tool | Upstream default | Available here | Purpose |
|------|------------------|----------------|---------|
| `activate_project` | on | no | Switch the Serena session to a named or pathed project. Needed on clients with a global MCP config (Codex, Claude Desktop) where the server isn't auto-bound to cwd. |
| `get_current_config` | on | no | Dumps the active Serena agent configuration (enabled tools, context, mode, project). Useful for debugging "why is tool X missing?". |
| `open_dashboard` | *(optional)* | yes | Opens Serena's local web dashboard (logs, token usage, tool stats) in the default browser. |
| `remove_project` | *(optional)* | no | Removes a project entry from Serena's global registry. |

---

## 6. Shell tool

| Tool | Upstream default | Available here | Purpose |
|------|------------------|----------------|---------|
| `execute_shell_command` | on | no | Runs an arbitrary shell command in the project root. In this repo Claude Code's `Bash` tool is used instead. |

---

## 7. Query-project tools (cross-project RAG)

| Tool | Upstream default | Available here | Purpose |
|------|------------------|----------------|---------|
| `list_queryable_projects` | *(optional)* | no | Lists other Serena projects that are registered and queryable from this session. |
| `query_project` | *(optional)* | no | Run a read-only Serena tool against a *different* registered project — lets an agent inspect external codebases without switching project context. |

---

## 8. JetBrains tools (all optional, IDE-backed alternatives)

Enabled only when Serena is paired with a JetBrains IDE via the JetBrains plugin; they use the IDE's indexing backend instead of an LSP. All are *(optional)* upstream and not available in this project.

- `jet_brains_find_symbol` — global/local symbol search via JetBrains index
- `jet_brains_find_declaration` — jump to declaration
- `jet_brains_find_implementations` — find implementations of an interface/abstract
- `jet_brains_find_referencing_symbols` — usages via JetBrains
- `jet_brains_get_symbols_overview` — file symbol tree via JetBrains
- `jet_brains_rename` — rename symbol/file/directory
- `jet_brains_move` *(BETA)* — move a symbol, file, or directory
- `jet_brains_inline_symbol` *(BETA)* — inline symbol at all call sites
- `jet_brains_safe_delete` *(BETA)* — safe-delete via JetBrains
- `jet_brains_type_hierarchy` — supertype/subtype hierarchy for a type

Use the LSP-backed `find_symbol` / `rename_symbol` / etc. unless the JetBrains bundle is explicitly configured.

---

## Practical notes for this project

- **Mandatory per `.docs/guides/mcp-tools.md`**: symbolic Serena tools for all code edits; Claude Code built-ins (`Read`/`Edit`/`Write`/`Glob`/`Grep`) for markdown and config. `sed`/`awk`/`echo >>` are banned for any file type.
- **First calls on a fresh session**: `check_onboarding_performed` → (if missing) `onboarding` → `list_memories` to orient.
- **Editing checklist**: `get_symbols_overview` → `find_symbol` (include_body only when needed) → `replace_symbol_body` / `insert_*_symbol` → `find_referencing_symbols` to sanity-check.
- **Refactor rename**: always prefer `rename_symbol` over search-and-replace.
- **Verifying enablement**: when a tool seems missing, `get_current_config` would be the upstream way to check, but it is not exposed here — inspect the MCP deferred tool list instead.

---

## When to update this memory

- A Serena release adds, removes, or renames a tool (check https://oraios.github.io/serena/01-about/035_tools.html).
- This project's MCP `args` change to enable/disable an optional tool — update the "Available here" column.
- A tool's recommended workflow changes materially.
