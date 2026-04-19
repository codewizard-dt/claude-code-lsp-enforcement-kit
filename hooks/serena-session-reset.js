#!/usr/bin/env node
'use strict';

/**
 * serena-session-reset.js — SessionStart hook
 *
 * Wipes stale Serena navigation state for the current cwd at session start.
 *
 * Without this, `nav_count` persists for 24h across sessions (see
 * serena-first-read-guard.js FLAG_EXPIRY_MS). A new session can inherit
 * "surgical mode" (nav_count >= 2) from previous work and freely Read
 * code files without ever calling Serena — a full bypass of the
 * Serena-first enforcement chain.
 *
 * After reset:
 *   - Gate 1 (warmup): first code Read BLOCKED until mcp__serena__get_symbols_overview
 *   - Gate 4: read #4 BLOCKED unless nav_count >= 1
 *   - Gate 5: read #6 BLOCKED unless nav_count >= 2
 *
 * Side-effect: first session call forces one warmup (~1 Serena call). Cheap.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const STATE_DIR = path.join(os.homedir(), '.claude', 'state');

function getFlagPath(cwd) {
  const hash = crypto.createHash('md5').update(cwd).digest('hex').slice(0, 12);
  return path.join(STATE_DIR, `lsp-ready-${hash}`);
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', d => { raw += d; });
process.stdin.on('end', () => {
  let cwd = process.cwd();
  try {
    const data = JSON.parse(raw || '{}');
    if (data.cwd && typeof data.cwd === 'string') cwd = data.cwd;
  } catch { /* ignore */ }

  const flagPath = getFlagPath(cwd);

  try {
    if (fs.existsSync(flagPath)) {
      fs.unlinkSync(flagPath);
    }
  } catch { /* silent: hook must never block session start */ }

  process.exit(0);
});
