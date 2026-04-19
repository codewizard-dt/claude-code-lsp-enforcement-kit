# Task Completion Checklist

## There is no automated test/lint pipeline
- No `npm test`, no `npm run lint`, no pre-commit hook enforcing checks.
- **Verification is behavioural**: did the hook do what it claims?

## When changing a hook
1. **Manual smoke test** via stdin: `echo '<json>' | node hooks/<hook>.js` — check decision and structured output.
2. **Check all call sites of any shared lib function** (`hooks/lib/serena.js`) — changes ripple to every hook that consumes it.
3. **Re-run `bash install.sh`** locally if you touched hook filenames or added new matchers — installer registers the matchers list, so new hooks need installer changes.
4. **Verify with `bash scripts/lsp-status.sh`** — confirms settings.json registration count matches hooks.
5. **Update `CHANGELOG.md`** under `[Unreleased]` with `Added` / `Changed` / `Fixed` / `Security` subsection. Not optional — the changelog is the authoritative history.
6. **If user-facing behaviour changed** (new gate threshold, new allow/block list entry, new provider) — update `README.md` sections too.

## When changing the installer
1. Re-run it on a clean `~/.claude/settings.json` (back it up first) to confirm idempotency.
2. Confirm `lsp-status.sh` still reports `Hooks installed: 7/7` (or new count) and matching settings registration counts.

## When bumping version
- Add dated section to `CHANGELOG.md` (move items from `[Unreleased]`).
- Commit with conventional prefix: `feat:`, `fix:`, `docs:`, `chore:`, or `feat(security):`.

## Security-sensitive changes
- `SECURITY.md` is the public disclosure policy.
- v2.1 release notes document the audit template ("mandatory `deep-security-reviewer` audit"). Any new hook or pattern-matching change should think about: fail-open on crash, unicode/zero-width bypass, substring anchoring, case-sensitivity, pipe-ordering in shell detection.
