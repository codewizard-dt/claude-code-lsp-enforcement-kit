# serena-tool-map.yaml — Canonical Tool Reference

## What it is
`serena-tool-map.yaml` (project root) documents the full mapping between Serena MCP tools and the Claude Code built-ins they replace. It is a doc-only artifact — no validator script, no runtime role.

## Contents (as of 2026-04-18)
44 tools across 8 groups:
- **symbol** (9): find_symbol, find_referencing_symbols, get_symbols_overview, insert_after_symbol, insert_before_symbol, rename_symbol, replace_symbol_body, restart_language_server, safe_delete_symbol
- **file** (9): read_file, create_text_file, list_dir, find_file, search_for_pattern, replace_content, replace_lines, insert_at_line, delete_lines
- **memory** (6): list_memories, read_memory, write_memory, edit_memory, rename_memory, delete_memory
- **workflow** (3): initial_instructions, check_onboarding_performed, onboarding
- **config** (4): activate_project, get_current_config, open_dashboard, remove_project
- **shell** (1): execute_shell_command
- **query** (2): list_queryable_projects, query_project
- **jetbrains** (10): jet_brains_* — all optional/IDE-only

## Schema per entry
```yaml
- tool: <name>
  category: symbol | file | memory | workflow | config | shell | query | jetbrains
  serena_status: enabled | optional | jetbrains-only
  claude_tools_replaced:
    - tool: <Claude tool>
      use_case: <description>
  enforcing_hook: <filename> | null
  notes: <prose>
```

## Hook enforcing_hook values used
- `serena-first-guard.js` — symbol tools (find_symbol, find_referencing_symbols)
- `serena-first-read-guard.js` — get_symbols_overview, read_file
- `serena-first-glob-guard.js` — find_file, list_dir (partial)
- `serena-bash-grep-block.js` — search_for_pattern, list_dir, find_file (bash path)
- All other tools: `null` (policy-only, no hook enforcement)
