'use strict';

/**
 * serena.js — shared helper for Serena-first enforcement hooks
 *
 * Single-provider helper that maps high-level navigation intents
 * ("find definition", "find references") to Serena MCP tool names
 * and produces block-message copy that consumers render verbatim.
 *
 * Serena (https://github.com/oraios/serena — MIT) provides high-level
 * symbolic tools with multi-language support via solidlsp.
 *
 * Claude Code MCP tool naming has two forms:
 *   mcp__serena__<tool>                          — standalone server
 *   mcp__plugin_<plugin>_serena__<tool>          — plugin-bundled server
 *
 * Both forms are recognised by isLspProviderTool / getTrackerToolNameRegex.
 *
 * No network, no MCP runtime introspection, no dependency on Serena being
 * installed — detection (if used) reads user-level Claude Code config.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();

// ── Serena constants ───────────────────────────────────────────────────────
const SERENA_PREFIX = 'mcp__serena__';
const SERENA_LABEL  = 'Serena';
const SERENA_TOKEN  = 'serena';

// First tool to call when understanding a file. Doubles as Gate 1 warmup.
const WARMUP_TOOL  = 'get_symbols_overview';
const WARMUP_NOTE  = "Serena's 'first tool to understand a file'";

// Abstract navigation intent → Serena tool name.
// Intents with no direct Serena equivalent fall back to find_symbol.
const TOOLS = {
  definition:       'find_symbol',
  references:       'find_referencing_symbols',
  symbol_search:    'find_symbol',
  implementation:   'find_symbol',
  incoming_calls:   'find_referencing_symbols',
  overview:         'get_symbols_overview',
  // Intents Serena does not expose directly — consumers should fall back
  // to symbol_search when these are null.
  hover:            null,
  diagnostics:      null,
  outgoing_calls:   null,
};

// Plugin-wrapped form (compiled once at module load).
const PLUGIN_WRAPPED_RE = new RegExp(`^mcp__plugin_[^_]+_${SERENA_TOKEN}__`);

// ── Config-file readers ────────────────────────────────────────────────────
function readJsonSilent(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

/**
 * Minimal presence check: scans ~/.claude.json mcpServers for a `serena` key.
 * Returns true if Serena is registered as an MCP server.
 */
function hasSerena() {
  const candidates = [
    path.join(HOME, '.claude.json'),
    path.join(HOME, '.claude', 'settings.json'),
    path.join(HOME, '.claude', 'mcp.json'),
    path.join(HOME, '.mcp.json'),
    path.join(process.cwd(), '.mcp.json'),
  ];
  for (const p of candidates) {
    const data = readJsonSilent(p);
    const servers = data?.mcpServers;
    if (servers && typeof servers === 'object') {
      for (const name of Object.keys(servers)) {
        if (String(name).toLowerCase() === SERENA_TOKEN) return true;
      }
    }
  }
  return false;
}

// ── Public API ─────────────────────────────────────────────────────────────

/**
 * Returns the list of active providers. Kept for backward compatibility
 * with existing consumers; in Serena-only mode this is always ['serena'].
 */
function detectProviders() {
  return ['serena'];
}

function resolveTool(intent) {
  return TOOLS[intent] || TOOLS.symbol_search;
}

/**
 * Build a single-line Serena suggestion for a symbol and navigation intent.
 *
 * @param {string} symbol  The code symbol to navigate to
 * @param {string} intent  One of the keys of TOOLS
 * @param {string} indent  Leading whitespace (default "  ")
 */
function buildSuggestion(symbol, intent, indent = '  ') {
  const tool = resolveTool(intent);
  const safeSym = String(symbol).replace(/"/g, '\\"');
  return `${indent}${SERENA_PREFIX}${tool}("${safeSym}")`;
}

/**
 * Warmup instructions for Gate 1 in serena-first-read-guard.js.
 * Returns an array of human-readable lines.
 */
function buildWarmupInstructions(indent = '  ') {
  return [
    `${indent}${SERENA_PREFIX}${WARMUP_TOOL}(<any project file>)`,
    `${indent}  → ${WARMUP_NOTE}`,
  ];
}

/**
 * Build a copy-pasteable Serena warmup call parametrized by the actual
 * file the agent is about to read:
 *   mcp__serena__get_symbols_overview("<path>")
 *
 * This call both unblocks Gate 1 and contributes to Gates 4/5.
 * Returns '' if filePath is empty.
 */
function buildFileWarmupCall(filePath, indent = '  ') {
  if (!filePath) return '';
  const safeFile = String(filePath).replace(/"/g, '\\"');
  return `${indent}${SERENA_PREFIX}${WARMUP_TOOL}("${safeFile}")`;
}

/**
 * Returns a regex fragment that matches Serena tool_name strings for
 * PostToolUse matcher generation. Matches standalone and plugin-wrapped.
 */
function getTrackerToolNameRegex() {
  return `mcp__(?:plugin_[^_]+_)?${SERENA_TOKEN}__`;
}

/**
 * Check whether a tool_name string is a Serena tool call.
 *   mcp__serena__find_symbol                → true
 *   mcp__plugin_foo_serena__find_symbol     → true
 *   mcp__foo__bar                           → false
 */
function isLspProviderTool(toolName) {
  if (!toolName || typeof toolName !== 'string') return false;
  if (!toolName.startsWith('mcp__')) return false;
  if (toolName.startsWith(SERENA_PREFIX)) return true;
  if (PLUGIN_WRAPPED_RE.test(toolName)) return true;
  return false;
}

/**
 * Structured suggestion list for programmatic consumers. Shape:
 *   [{ provider, label, tool, args, displayTool }]
 *
 * Always returns a single-element array (Serena-only), kept as an array
 * so Step 2 consumers can iterate without branching.
 */
function buildStructuredSuggestions(symbol, intent) {
  const tool = resolveTool(intent);
  const safeSym = String(symbol).replace(/"/g, '\\"');
  return [{
    provider:    'serena',
    label:       SERENA_LABEL,
    tool:        `${SERENA_PREFIX}${tool}`,
    args:        { query: String(symbol) },
    displayTool: `${SERENA_PREFIX}${tool}("${safeSym}")`,
  }];
}

/**
 * Assemble a structured block response for blocking hooks to emit via
 * console.log(JSON.stringify(...)). Preserves `decision` and `reason`
 * (backward compatible) and adds `hook`, `symbols`, `intent`, `providers`,
 * `suggestions[]`.
 */
function buildStructuredBlockResponse({ hook, symbols, intent, reason }) {
  const providers = detectProviders();
  const suggestions = [];
  const symbolList = Array.isArray(symbols) ? symbols : [];
  for (const sym of symbolList) {
    for (const s of buildStructuredSuggestions(sym, intent)) {
      suggestions.push({ symbol: String(sym), ...s });
    }
  }
  return {
    decision: 'block',
    reason:   String(reason ?? ''),
    hook:     String(hook ?? ''),
    symbols:  symbolList.map(String),
    intent:   String(intent ?? ''),
    providers,
    suggestions,
  };
}

module.exports = {
  // Constants
  SERENA_PREFIX,
  WARMUP_TOOL,
  // Presence detection
  hasSerena,
  detectProviders,
  // Message builders
  buildSuggestion,
  buildWarmupInstructions,
  buildFileWarmupCall,
  buildStructuredSuggestions,
  buildStructuredBlockResponse,
  // Tool-name matchers
  getTrackerToolNameRegex,
  isLspProviderTool,
};
