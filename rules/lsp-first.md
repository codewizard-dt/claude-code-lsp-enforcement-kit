# LSP-First Navigation (Serena) (CRITICAL)

When the Serena MCP server is connected, ALL agents MUST use Serena's semantic tools over Grep/Glob for code navigation. Serena is an LSP-backed provider — LSP-First still applies; the tool names below are the Serena surface.

| Task | Serena Tool |
|------|-------------|
| Definition | `find_symbol` (with `include_body=true` when the body is needed) |
| References | `find_referencing_symbols` |
| Symbol search | `find_symbol` (with `name_path_pattern`) |
| Overview / first-tool on a file | `get_symbols_overview` |

Grep/Glob = fallback ONLY when Serena returns empty or you are searching non-symbol text (comments, strings, config values, prose).
