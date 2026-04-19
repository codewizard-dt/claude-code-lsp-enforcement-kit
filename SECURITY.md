# Security Policy

## Scope

The LSP Enforcement Kit is a collection of Node.js hooks that run on every Claude Code tool invocation. They read user-level Claude Code config (`~/.claude.json`, `~/.claude/settings.json`) and make block/allow decisions based on user-controlled input (`tool_input.pattern`, `tool_input.command`, `tool_input.file_path`, etc.).

Security issues in these hooks are taken seriously because:
- They run with user privileges on every tool call
- They read config files that may contain API keys or tokens
- They make security-adjacent decisions (allow/block code navigation)
- A fail-open bug silently disables enforcement for all users of the kit

## Reporting

**Do not open a public issue** for security vulnerabilities. Instead:

1. **Preferred:** open a [GitHub Security Advisory](https://github.com/nesaminua/claude-code-lsp-enforcement-kit/security/advisories/new) in this repo. Private by default, lets us coordinate a fix before disclosure.
2. **Alternative:** email the maintainer via the GitHub profile contact at [@nesaminua](https://github.com/nesaminua).

Please include:
- Affected version(s) (`cat ~/.claude/hooks/lib/serena.js | head -5` or the git tag you installed)
- A minimal reproduction (example `tool_input` JSON that triggers the issue)
- Impact assessment (fail-open bypass? information disclosure? ReDoS? arbitrary write?)
- Your proposed fix (optional but appreciated)

## Scope of interest

We care about:
- **Fail-open bypasses** — input that crashes a hook and causes Claude Code to treat the crash as passthrough, letting a blocked tool call through. These are the worst class of bug in an enforcement layer.
- **Injection** — code/command injection via unsanitized `tool_input` fields embedded into block messages or state files.
- **Information disclosure** — config contents (API keys, tokens, paths) leaking to stdout/stderr via block messages or state serialisation.
- **Path traversal** — state file writes escaping `~/.claude/state/`.
- **ReDoS** — regexes in symbol detection with catastrophic backtracking on adversarial input.
- **Prototype pollution** — via `JSON.parse` of untrusted input or user config.
- **Supply chain** — third-party dependencies introducing any of the above. (The kit currently has zero npm dependencies. This is intentional.)

## Out of scope

- Claude Code itself or the Serena MCP server — report upstream.
- Bypasses via legitimate tools that are intentionally allowed (e.g. non-symbol `Grep` on lowercase phrases, `Bash(cat)`, `git grep`).
- Theoretical vulnerabilities without a working reproduction.
- The `serena-session-reset.js` hook legitimately wiping stale state — that's the designed behaviour, not a bug.

## Response

- Acknowledgement within 72 hours of report.
- Severity triage and fix timeline within 1 week for CRITICAL/HIGH issues.
- Coordinated disclosure after the fix is released.
- Credit in the changelog (unless you prefer anonymity).

## Audit history

Every release that touches hook logic is audited by a deep security review (see `CHANGELOG.md` → "Security" sections). v2.1.0 fixed one MEDIUM (type-confusion fail-open) and four LOW findings from that process.
