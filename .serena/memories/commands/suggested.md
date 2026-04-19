# Suggested Commands

## Install / reinstall (idempotent)
```bash
bash install.sh                    # macOS/Linux
pwsh ./install.ps1                 # Windows (or powershell -ExecutionPolicy Bypass -File ./install.ps1)
```
Safe to re-run on upgrades — deduped by command path in `settings.json`.

## Verify install / diagnose
```bash
bash scripts/lsp-status.sh         # from repo
bash ~/.claude/scripts/lsp-status.sh   # from anywhere (after install copies it)
```
Prints: hook count (7/7), settings registration counts, detected providers, current cwd state (warmup, nav_count, read_count, last tool), gate verdict for next Read.

## Manual unit test of a hook
Each hook reads JSON on stdin. Quick smoke test:
```bash
echo '{"tool_input":{"pattern":"handleSubmit"}}' | node hooks/serena-first-guard.js
# expect: exit 0 with JSON decision=block on stdout
```

## Git workflow
```bash
git status
git log --oneline -20
git diff
```
No lint/test/format targets — **there is no `npm test`, no `npm run lint`, no CI**. Verification is manual (runtime behavior + `lsp-status.sh`).

## Darwin-specific notes
- macOS `sed -i` needs `''` first arg (e.g. `sed -i '' 's/a/b/' file`). **But never use `sed` on this repo's files** — use the `Edit` tool per `.docs/guides/mcp-tools.md`.
- No GNU-specific flags in scripts (portable `#!/usr/bin/env bash`).

## Releasing (historical pattern)
Version bump touches: `README.md` (badges mention version implicitly via releases URL), `CHANGELOG.md` (add dated section above previous). Release commits follow conventional prefix: `feat:`, `fix:`, `docs:`, `chore:`.
