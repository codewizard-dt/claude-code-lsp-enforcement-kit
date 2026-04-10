'use strict';

/**
 * detect-lsp-provider.js — shared helper for LSP enforcement hooks
 *
 * Detects which LSP-providing MCP servers the user has installed and
 * maps high-level navigation intents ("find definition", "find references")
 * to the correct provider-specific tool names.
 *
 * Supports:
 *   - cclsp         (standalone MCP server, or via typescript-lsp plugin)
 *   - Serena        (https://github.com/oraios/serena — MIT, high-level
 *                    symbol tools, multi-language)
 *   - generic       (fallback — shows neutral hints)
 *
 * Why provider-aware? Before this helper, block messages hardcoded
 * `mcp__cclsp__*` tool names. Users running Serena (or both) saw broken
 * suggestions like "use mcp__cclsp__find_workspace_symbols" even though
 * their LSP tools were actually `mcp__serena__find_symbol`.
 *
 * Detection reads user-level Claude Code config files only. No network,
 * no MCP runtime introspection, no dependency on either provider being
 * installed.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();

// ── Provider registry ──────────────────────────────────────────────────────
// Each entry maps abstract navigation intents to concrete tool names.
// Add new providers here when their MCP servers become popular.
//
// Claude Code MCP tool naming has two forms (verified via anthropics/claude-code docs):
//   mcp__<server>__<tool>                          — standalone server (in ~/.claude.json mcpServers)
//   mcp__plugin_<plugin>_<server>__<tool>          — plugin-bundled server
//
// We handle both by matching the server-name token anywhere after an `mcp__`
// prefix, rather than requiring a fixed prefix string.
const PROVIDERS = {
  cclsp: {
    label:        'cclsp',
    // Preferred prefix for generating NEW suggestions (standalone form).
    prefix:       'mcp__cclsp__',
    // Server-name token for matching EXISTING tool calls. Matches both
    // `mcp__cclsp__*` and `mcp__plugin_*cclsp*__*` variants.
    matchToken:   'cclsp',
    // abstract intent → cclsp tool name
    tools: {
      definition:       'find_definition',
      references:       'find_references',
      symbol_search:    'find_workspace_symbols',
      implementation:   'find_implementation',
      hover:            'get_hover',
      diagnostics:      'get_diagnostics',
      incoming_calls:   'get_incoming_calls',
      outgoing_calls:   'get_outgoing_calls',
    },
    // First call to make on session start — primes the TS project
    warmup: { tool: 'get_diagnostics', note: 'primes TS server (cclsp upstream bug #43 workaround)' },
  },
  serena: {
    label:        'Serena',
    prefix:       'mcp__serena__',
    matchToken:   'serena',
    tools: {
      // Serena's find_symbol is unified: returns definitions with optional body
      definition:       'find_symbol',
      references:       'find_referencing_symbols',
      symbol_search:    'find_symbol',
      // Serena has no direct cclsp equivalents for these, fall back to find_symbol
      implementation:   'find_symbol',
      hover:             null,
      diagnostics:       null,
      incoming_calls:   'find_referencing_symbols',
      outgoing_calls:    null,
      // Serena-only: high-level "start here" tool
      overview:         'get_symbols_overview',
    },
    // Serena's recommended "first tool to call when understanding a file"
    warmup: { tool: 'get_symbols_overview', note: "Serena's 'first tool to understand a file'" },
  },
};

// ── Config-file readers ────────────────────────────────────────────────────
function readJsonSilent(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function collectMcpServerNames() {
  const names = new Set();
  const candidates = [
    path.join(HOME, '.claude.json'),           // primary Claude Code MCP config
    path.join(HOME, '.claude', 'settings.json'),
    path.join(HOME, '.claude', 'mcp.json'),
    path.join(HOME, '.mcp.json'),              // project-level (cwd fallback)
    path.join(process.cwd(), '.mcp.json'),
  ];

  for (const p of candidates) {
    const data = readJsonSilent(p);
    const servers = data?.mcpServers;
    if (servers && typeof servers === 'object') {
      for (const name of Object.keys(servers)) {
        names.add(String(name).toLowerCase());
      }
    }
  }

  return names;
}

function hasBundledTypescriptLspPlugin() {
  const settings = readJsonSilent(path.join(HOME, '.claude', 'settings.json'));
  return Boolean(settings?.enabledPlugins?.['typescript-lsp@claude-plugins-official']);
}

// ── Public API ─────────────────────────────────────────────────────────────

/**
 * Returns an array of provider keys active on this machine, e.g. ['cclsp'],
 * ['serena'], ['cclsp', 'serena'], or [] if none detected.
 */
function detectProviders() {
  const active = new Set();
  const mcpNames = collectMcpServerNames();

  // cclsp: standalone MCP server OR bundled via typescript-lsp plugin
  if (mcpNames.has('cclsp') || hasBundledTypescriptLspPlugin()) {
    active.add('cclsp');
  }

  // Serena: standalone MCP server registered under the conventional key
  if (mcpNames.has('serena')) {
    active.add('serena');
  }

  return Array.from(active);
}

/**
 * Build a multi-line suggestion block for a given symbol and navigation intent.
 * Shows suggestions for ALL detected providers (or a generic hint if none).
 *
 * @param {string} symbol  The code symbol to navigate to
 * @param {string} intent  One of: 'definition', 'references', 'symbol_search',
 *                         'implementation', 'overview'
 * @param {string} indent  Leading whitespace for each line (default "  ")
 */
function buildSuggestion(symbol, intent, indent = '  ') {
  const providers = detectProviders();

  if (providers.length === 0) {
    return (
      `${indent}(no LSP MCP server detected — install cclsp or Serena)\n` +
      `${indent}Generic: your LSP MCP's find_definition / find_references / find_workspace_symbols`
    );
  }

  const lines = [];
  for (const key of providers) {
    const prov = PROVIDERS[key];
    if (!prov) continue;
    const toolName = prov.tools[intent] || prov.tools.symbol_search;
    if (!toolName) continue;
    lines.push(`${indent}${prov.prefix}${toolName}("${symbol}")  (${prov.label})`);
  }
  return lines.join('\n');
}

/**
 * Get warmup call instructions for Gate 1 in lsp-first-read-guard.js.
 * Returns an array of human-readable lines.
 */
function buildWarmupInstructions(indent = '  ') {
  const providers = detectProviders();

  if (providers.length === 0) {
    return [
      `${indent}No LSP MCP server detected.`,
      `${indent}Install one of:`,
      `${indent}  • cclsp — https://github.com/ktnyt/cclsp (TypeScript/JavaScript)`,
      `${indent}  • Serena — https://github.com/oraios/serena (multi-language)`,
      `${indent}Then call any LSP symbol tool to warm up and unlock Read gates.`,
    ];
  }

  const lines = [];
  for (const key of providers) {
    const prov = PROVIDERS[key];
    if (!prov?.warmup) continue;
    lines.push(`${indent}${prov.prefix}${prov.warmup.tool}(<any project file>)`);
    lines.push(`${indent}  → ${prov.warmup.note}`);
  }
  return lines;
}

/**
 * Returns a regex fragment that matches tool_name strings for all known
 * providers (used in PostToolUse matcher generation). Matches both
 * standalone and plugin-wrapped forms.
 */
function getTrackerToolNameRegex() {
  const tokens = Object.values(PROVIDERS).map(p => p.matchToken);
  // Match `mcp__<token>__*` OR `mcp__plugin_<anything>_<token>__*`
  return tokens
    .map(tok => `mcp__(?:plugin_[^_]+_)?${tok}__`)
    .join('|');
}

/**
 * Check whether a tool_name string belongs to any known LSP provider.
 * Handles both standalone and plugin-wrapped MCP server naming:
 *   mcp__cclsp__find_definition                       → true (standalone)
 *   mcp__plugin_typescript-lsp_cclsp__find_definition → true (plugin-wrapped)
 *   mcp__serena__find_symbol                          → true
 *   mcp__foo__bar                                     → false
 */
function isLspProviderTool(toolName) {
  if (!toolName || typeof toolName !== 'string') return false;
  if (!toolName.startsWith('mcp__')) return false;
  for (const key of Object.keys(PROVIDERS)) {
    const token = PROVIDERS[key].matchToken;
    // Standalone form: mcp__<token>__
    if (toolName.startsWith(`mcp__${token}__`)) return true;
    // Plugin-wrapped form: mcp__plugin_<plugin>_<token>__
    const pluginRegex = new RegExp(`^mcp__plugin_[^_]+_${token}__`);
    if (pluginRegex.test(toolName)) return true;
  }
  return false;
}

module.exports = {
  PROVIDERS,
  detectProviders,
  buildSuggestion,
  buildWarmupInstructions,
  getTrackerToolNameRegex,
  isLspProviderTool,
};
