#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
RULES_DIR="$CLAUDE_DIR/rules"
STATE_DIR="$CLAUDE_DIR/state"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "=== LSP Enforcement Kit — Install ==="
echo ""

# 1. Create directories
mkdir -p "$HOOKS_DIR" "$HOOKS_DIR/lib" "$RULES_DIR" "$STATE_DIR"
echo "[1/4] Directories ready"

# 2. Remove old (pre-Serena) hook files, then copy new hooks + shared lib + rule
OLD_HOOKS=(
  lsp-first-guard.js
  lsp-first-glob-guard.js
  lsp-first-read-guard.js
  lsp-pre-delegation.js
  lsp-session-reset.js
  lsp-usage-tracker.js
  bash-grep-block.js
)
for f in "${OLD_HOOKS[@]}"; do
  rm -f "$HOOKS_DIR/$f"
done
rm -f "$HOOKS_DIR/lib/detect-lsp-provider.js"

cp "$SCRIPT_DIR/hooks/"*.js "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/lib/"*.js "$HOOKS_DIR/lib/"
cp "$SCRIPT_DIR/rules/lsp-first.md" "$RULES_DIR/"
echo "[2/4] Copied 7 hooks + lib + 1 rule (old LSP hooks removed)"

# 3. Merge into settings.json (node for safe JSON manipulation)
node -e "
const fs = require('fs');
const path = '$SETTINGS';

let settings = {};
if (fs.existsSync(path)) {
  try { settings = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
}

// Old hook filenames to purge from settings.json on every install
const OLD_HOOK_FILES = new Set([
  'lsp-first-guard.js',
  'lsp-first-glob-guard.js',
  'lsp-first-read-guard.js',
  'lsp-pre-delegation.js',
  'lsp-session-reset.js',
  'lsp-usage-tracker.js',
  'bash-grep-block.js',
]);

function isOldHookCommand(cmd) {
  if (!cmd || typeof cmd !== 'string') return false;
  for (const f of OLD_HOOK_FILES) {
    if (cmd.endsWith('/' + f) || cmd.endsWith(' ' + f) || cmd.endsWith(f)) {
      // Tighten: require separator so 'serena-bash-grep-block.js' is not matched
      const idx = cmd.lastIndexOf(f);
      const before = cmd.charAt(idx - 1);
      if (before === '/' || before === ' ' || idx === 0) return true;
    }
  }
  return false;
}

function stripOldEntries(arr) {
  if (!Array.isArray(arr)) return [];
  const filtered = [];
  for (const entry of arr) {
    if (!entry || !Array.isArray(entry.hooks)) { filtered.push(entry); continue; }
    const keptHooks = entry.hooks.filter(h => !isOldHookCommand(h && h.command));
    if (keptHooks.length === 0) continue; // drop whole entry if all hooks were old
    filtered.push(Object.assign({}, entry, { hooks: keptHooks }));
  }
  return filtered;
}

// Remove the typescript-lsp plugin (kit is Serena-only now)
if (settings.enabledPlugins && 'typescript-lsp@claude-plugins-official' in settings.enabledPlugins) {
  delete settings.enabledPlugins['typescript-lsp@claude-plugins-official'];
}

// Hook entries to add (new Serena-era filenames)
const preToolUse = [
  { matcher: 'Grep',  hooks: [{ type: 'command', command: 'node ~/.claude/hooks/serena-first-guard.js' }] },
  { matcher: 'Glob',  hooks: [{ type: 'command', command: 'node ~/.claude/hooks/serena-first-glob-guard.js' }] },
  { matcher: 'Bash',  hooks: [{ type: 'command', command: 'node ~/.claude/hooks/serena-bash-grep-block.js' }] },
  { matcher: 'Read',  hooks: [{ type: 'command', command: 'node ~/.claude/hooks/serena-first-read-guard.js' }] },
  { matcher: 'Agent', hooks: [{ type: 'command', command: 'node ~/.claude/hooks/serena-pre-delegation.js' }] },
];

const postToolUse = [
  {
    matcher: 'mcp__serena__find_symbol|mcp__serena__find_referencing_symbols|mcp__serena__get_symbols_overview|mcp__serena__find_file|mcp__serena__search_for_pattern|mcp__serena__list_dir',
    hooks: [{ type: 'command', command: 'node ~/.claude/hooks/serena-usage-tracker.js' }],
  },
];

const sessionStart = [
  { matcher: 'true', hooks: [{ type: 'command', command: 'node ~/.claude/hooks/serena-session-reset.js' }] },
];

if (!settings.hooks) settings.hooks = {};
if (!settings.hooks.PreToolUse) settings.hooks.PreToolUse = [];
if (!settings.hooks.PostToolUse) settings.hooks.PostToolUse = [];
if (!settings.hooks.SessionStart) settings.hooks.SessionStart = [];

// Strip old lsp-* hook entries before merging new ones
settings.hooks.PreToolUse   = stripOldEntries(settings.hooks.PreToolUse);
settings.hooks.PostToolUse  = stripOldEntries(settings.hooks.PostToolUse);
settings.hooks.SessionStart = stripOldEntries(settings.hooks.SessionStart);

// Dedupe: skip if command already registered
function hasHook(arr, command) {
  return arr.some(entry =>
    entry.hooks && entry.hooks.some(h => h.command === command)
  );
}

for (const entry of preToolUse) {
  if (!hasHook(settings.hooks.PreToolUse, entry.hooks[0].command)) {
    settings.hooks.PreToolUse.push(entry);
  }
}

for (const entry of postToolUse) {
  if (!hasHook(settings.hooks.PostToolUse, entry.hooks[0].command)) {
    settings.hooks.PostToolUse.push(entry);
  }
}

for (const entry of sessionStart) {
  if (!hasHook(settings.hooks.SessionStart, entry.hooks[0].command)) {
    settings.hooks.SessionStart.push(entry);
  }
}

fs.writeFileSync(path, JSON.stringify(settings, null, 2));
"
echo "[3/4] settings.json updated (merged, old entries purged)"

# 4. Verify
echo "[4/4] Verifying..."
HOOKS_COUNT=$(ls "$HOOKS_DIR"/serena-*.js 2>/dev/null | wc -l | tr -d ' ')
RULE_OK=$( [ -f "$RULES_DIR/lsp-first.md" ] && echo "yes" || echo "no" )
SERENA_OK=$(node -e "
  try {
    const cfg = JSON.parse(require('fs').readFileSync(process.env.HOME + '/.claude.json','utf8'));
    const servers = (cfg && cfg.mcpServers) || {};
    console.log(servers.serena ? 'yes' : 'no');
  } catch { console.log('unknown'); }
")

echo ""
echo "  Hooks installed:  $HOOKS_COUNT/7"
echo "  Rule installed:   $RULE_OK"
echo "  Serena MCP:       $SERENA_OK"
echo "  State directory:  $([ -d "$STATE_DIR" ] && echo 'yes' || echo 'no')"
echo ""

if [ "$HOOKS_COUNT" -eq 7 ] && [ "$RULE_OK" = "yes" ]; then
  echo "Done. Restart Claude Code to activate."
  if [ "$SERENA_OK" != "yes" ]; then
    echo "NOTE: Serena MCP not detected. Install it with:"
    echo "  claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant"
  fi
else
  echo "WARNING: Some components missing. Check output above."
fi
