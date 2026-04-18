# LSP Enforcement Kit — Project Overview

## Purpose
A physical-enforcement layer for Claude Code that forces **LSP-first code navigation** over Grep/Read. Claude Code's default (Grep → Read → Read → Read) burns tokens; LSP (`find_definition`, `find_references`, etc.) is ~40× cheaper for the same answer. A CLAUDE.md rule helps ~60% of the time; hooks make it 100%.

Distribution: clone repo + run `install.sh` (or `install.ps1`). The installer copies hooks to `~/.claude/hooks/` and merges entries into `~/.claude/settings.json` idempotently.

## Current version
**v2.3.2** (2026-04-14). The main README is under `/README.md`; authoritative change history is `CHANGELOG.md`.

## What ships
- **7 hook JS files** under `hooks/` (+ 1 shared lib `hooks/lib/detect-lsp-provider.js`)
- **1 rule** `rules/lsp-first.md` (LSP-first navigation instruction copied to `~/.claude/rules/`)
- **2 installers**: `install.sh` (bash, macOS/Linux) and `install.ps1` (PowerShell, Windows)
- **1 health check**: `scripts/lsp-status.sh`
- **Docs**: `README.md`, `CHANGELOG.md`, `SECURITY.md`, `.docs/guides/*`

## Providers supported
v2.1+ is provider-aware. Detects which LSP MCP server(s) the user has (cclsp, Serena, both, or neither) by reading `~/.claude.json`, `~/.claude/settings.json`, and project-level `.mcp.json`, then tailors block-message suggestions. Adding a provider = one entry in the `PROVIDERS` registry in `hooks/lib/detect-lsp-provider.js`.

## Project name and repo
- Local path: `/Users/davidtaylor/Repositories/claude-code-lsp-enforcement-kit`
- GitHub: `github.com/nesaminua/claude-code-lsp-enforcement-kit`
- License: MIT
