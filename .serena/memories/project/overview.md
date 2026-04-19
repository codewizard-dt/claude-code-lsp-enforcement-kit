# LSP Enforcement Kit — Project Overview

## Purpose
A physical-enforcement layer for Claude Code that forces **Serena-first code navigation** over Grep/Read. Claude Code's default (Grep → Read → Read → Read) burns tokens; Serena's LSP-backed symbolic tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, etc.) are ~40× cheaper for the same answer. A CLAUDE.md rule helps ~60% of the time; hooks make it 100%.

Distribution: clone repo + run `install.sh` (or `install.ps1`). The installer copies hooks to `~/.claude/hooks/`, merges entries into `~/.claude/settings.json` idempotently, and unlinks any pre-v3.0 `lsp-*.js` hook files.

## Current version
**v3.0.0** (2026-04-18) — breaking: Serena-only, all hooks renamed `lsp-*` → `serena-*`. The main README is `/README.md`; authoritative change history is `CHANGELOG.md`.

## What ships
- **7 hook JS files** under `hooks/` (all `serena-*.js`) + 1 shared lib `hooks/lib/serena.js`
- **1 rule** `rules/lsp-first.md` (Serena-first navigation instruction copied to `~/.claude/rules/`)
- **2 installers**: `install.sh` (bash, macOS/Linux) and `install.ps1` (PowerShell, Windows) — both unlink old `lsp-*` files
- **1 health check**: `scripts/lsp-status.sh`
- **Docs**: `README.md`, `CHANGELOG.md`, `SECURITY.md`, `.docs/guides/*`, `.docs/tasks/*`

## Provider
Single provider: **Serena** (Oraios AI, MIT). cclsp and the `typescript-lsp` plugin were removed in v3.0. Hook matchers and block-message copy reference `mcp__serena__*` exclusively.

## Project name and repo
- Local path: `/Users/davidtaylor/Repositories/claude-code-lsp-enforcement-kit`
- GitHub: `github.com/nesaminua/claude-code-lsp-enforcement-kit`
- License: MIT
