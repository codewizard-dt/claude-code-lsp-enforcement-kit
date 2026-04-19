# .docs/ Structure, Task Lifecycle, Project Slash Commands

## `.docs/` layout
```
.docs/
├── guides/
│   ├── mcp-tools.md       # Mandatory MCP tool rules (Serena/Context7/Brave/Puppeteer) — read on session start
│   └── task-lifecycle.md  # Task/UAT file flow doc
├── tasks/
│   ├── active/    ← task files live here during work (+ active/README.md specifies task-file format)
│   ├── completed/
│   └── trashed/
└── uat/
    ├── pending/   ← UAT files created by /uat-generator live here
    ├── completed/
    ├── skipped/
    ├── trashed/
    └── screenshots/  (transient)
```

`tasks/completed/` holds the v3.0 refactor task (`001-serena-only-hooks.md`, UAT skipped via `/uat-skip`). The skeleton skip marker lives at `uat/skipped/001-serena-only-hooks.uat.md`. `tasks/active/` is currently empty.

## Task naming
`<NNN>-<short-slug>.md` for tasks, `<NNN>-<short-slug>.uat.md` for matching UATs. NNN is zero-padded sequential, unique across `active/ + completed/`.

## Happy-path lifecycle
```
/add-task          → creates in active/
/tackle            → implements (no file move)
/uat-generator     → creates UAT in pending/
/uat-walkthrough   → when all tests pass: active/→completed/, pending/→completed/
```

`/tackle` never moves the task file. Only `/uat-walkthrough` (all pass) or `/uat-skip` promote `active/→completed/`. A "pass" means every test is `[x] Pass` or `[SKIP: …]`, with no `[FAIL]` / `[FIXING]` markers.

## Project-local slash commands (`.claude/commands/`)
- **Task-related**: `add-task`, `update-task`, `tackle`, `trash-task`
- **UAT-related**: `uat-generator`, `uat-walkthrough`, `uat-auto`, `uat-skip`, `uat-auth`
- **Workflow**: `now` (plan + execute), `primer` (refresh from memories), `research` (deep research)
- **Quality**: `simplify` (review + simplify code), `lint` (lint diagnostics cycle)
- **Docs**: `update-docs`, `project-readme`
- **Git**: `git-commit`

## Authority hierarchy for tool usage
1. User's private `/Users/davidtaylor/.claude/rules/lsp-first.md` — LSP-first global rule (always in context)
2. Project `.docs/guides/mcp-tools.md` — mandatory MCP tool matrix for this repo
3. Installed hooks under `~/.claude/hooks/` — physical enforcement

When they conflict: hooks win (they block at tool-call time). Follow the guides to avoid tripping the hooks.
