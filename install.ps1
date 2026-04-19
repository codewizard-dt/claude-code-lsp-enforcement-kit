<#
.SYNOPSIS
    LSP Enforcement Kit installer for Windows (PowerShell).

.DESCRIPTION
    Installs 7 Serena-era hooks + shared lib to $env:USERPROFILE\.claude\hooks,
    removes any legacy lsp-*.js / bash-grep-block.js hook files from a prior
    install, merges hook registrations into $env:USERPROFILE\.claude\settings.json
    (without overwriting other entries — idempotent), strips the old
    typescript-lsp plugin if present, and creates the state directory.

    Mirrors the behaviour of install.sh on macOS/Linux. Safe to re-run:
    old hook entries are purged and new ones deduplicated by command path.

.EXAMPLE
    pwsh ./install.ps1
    powershell -ExecutionPolicy Bypass -File ./install.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ClaudeDir  = Join-Path $env:USERPROFILE '.claude'
$HooksDir   = Join-Path $ClaudeDir 'hooks'
$HooksLib   = Join-Path $HooksDir  'lib'
$RulesDir   = Join-Path $ClaudeDir 'rules'
$StateDir   = Join-Path $ClaudeDir 'state'
$Settings   = Join-Path $ClaudeDir 'settings.json'

Write-Host '=== LSP Enforcement Kit — Install ===' -ForegroundColor Cyan
Write-Host ''

# 1. Create directories
foreach ($dir in @($HooksDir, $HooksLib, $RulesDir, $StateDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}
Write-Host '[1/4] Directories ready'

# 2. Remove old (pre-Serena) hooks, then copy new hooks + shared lib + rule
$OldHooks = @(
    'lsp-first-guard.js',
    'lsp-first-glob-guard.js',
    'lsp-first-read-guard.js',
    'lsp-pre-delegation.js',
    'lsp-session-reset.js',
    'lsp-usage-tracker.js',
    'bash-grep-block.js'
)
foreach ($f in $OldHooks) {
    $p = Join-Path $HooksDir $f
    if (Test-Path $p) { Remove-Item -Path $p -Force }
}
$oldLib = Join-Path $HooksLib 'detect-lsp-provider.js'
if (Test-Path $oldLib) { Remove-Item -Path $oldLib -Force }

$SourceHooks = Join-Path $ScriptDir 'hooks'
$SourceLib   = Join-Path $SourceHooks 'lib'
$SourceRule  = Join-Path $ScriptDir 'rules\lsp-first.md'

Copy-Item -Path (Join-Path $SourceHooks '*.js') -Destination $HooksDir -Force
Copy-Item -Path (Join-Path $SourceLib   '*.js') -Destination $HooksLib -Force
if (Test-Path $SourceRule) {
    Copy-Item -Path $SourceRule -Destination $RulesDir -Force
}
Write-Host '[2/4] Copied 7 hooks + lib + 1 rule (old LSP hooks removed)'

# 3. Merge into settings.json
# PowerShell's ConvertFrom-Json returns PSCustomObject; we use hashtables
# for idempotent mutation, then re-serialise.
function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return @{} }
    try {
        $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
        $obj = $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($null -eq $obj) { return @{} }
        return $obj
    } catch {
        return @{}
    }
}

function Ensure-Key {
    param([hashtable]$Table, [string]$Key, $Default)
    if (-not $Table.ContainsKey($Key)) { $Table[$Key] = $Default }
}

function Has-HookCommand {
    param([array]$Array, [string]$Command)
    foreach ($entry in $Array) {
        if ($entry -and $entry.hooks) {
            foreach ($h in $entry.hooks) {
                if ($h.command -eq $Command) { return $true }
            }
        }
    }
    return $false
}

# Legacy hook filenames — any settings.json entry whose command ends in one
# of these is stripped before the new Serena entries are merged.
$LegacyHookFiles = @(
    'lsp-first-guard.js',
    'lsp-first-glob-guard.js',
    'lsp-first-read-guard.js',
    'lsp-pre-delegation.js',
    'lsp-session-reset.js',
    'lsp-usage-tracker.js',
    'bash-grep-block.js'
)

function Test-IsLegacyCommand {
    param([string]$Command)
    if ([string]::IsNullOrEmpty($Command)) { return $false }
    foreach ($f in $LegacyHookFiles) {
        # Require a separator before the filename so 'serena-bash-grep-block.js'
        # is not matched against 'bash-grep-block.js'.
        if ($Command -match ('(^|[/ \\])' + [regex]::Escape($f) + '$')) { return $true }
    }
    return $false
}

function Strip-LegacyEntries {
    param([array]$Array)
    if (-not $Array) { return @() }
    $out = @()
    foreach ($entry in $Array) {
        if (-not $entry -or -not $entry.hooks) { $out += ,$entry; continue }
        $keptHooks = @()
        foreach ($h in $entry.hooks) {
            if (-not (Test-IsLegacyCommand -Command $h.command)) { $keptHooks += ,$h }
        }
        if ($keptHooks.Count -eq 0) { continue }
        $entry.hooks = $keptHooks
        $out += ,$entry
    }
    return ,$out
}

$settings = Read-JsonFile -Path $Settings

# Remove the typescript-lsp plugin (kit is Serena-only now)
if ($settings.ContainsKey('enabledPlugins') -and $settings.enabledPlugins -and
    $settings.enabledPlugins.ContainsKey('typescript-lsp@claude-plugins-official')) {
    $settings.enabledPlugins.Remove('typescript-lsp@claude-plugins-official') | Out-Null
}

Ensure-Key -Table $settings -Key 'hooks' -Default @{}
Ensure-Key -Table $settings.hooks -Key 'PreToolUse'   -Default @()
Ensure-Key -Table $settings.hooks -Key 'PostToolUse'  -Default @()
Ensure-Key -Table $settings.hooks -Key 'SessionStart' -Default @()

# Purge legacy entries before adding new ones
$settings.hooks.PreToolUse   = Strip-LegacyEntries -Array $settings.hooks.PreToolUse
$settings.hooks.PostToolUse  = Strip-LegacyEntries -Array $settings.hooks.PostToolUse
$settings.hooks.SessionStart = Strip-LegacyEntries -Array $settings.hooks.SessionStart

$preToolUse = @(
    @{ matcher = 'Grep';  hooks = @(@{ type = 'command'; command = 'node ~/.claude/hooks/serena-first-guard.js' }) },
    @{ matcher = 'Glob';  hooks = @(@{ type = 'command'; command = 'node ~/.claude/hooks/serena-first-glob-guard.js' }) },
    @{ matcher = 'Bash';  hooks = @(@{ type = 'command'; command = 'node ~/.claude/hooks/serena-bash-grep-block.js' }) },
    @{ matcher = 'Read';  hooks = @(@{ type = 'command'; command = 'node ~/.claude/hooks/serena-first-read-guard.js' }) },
    @{ matcher = 'Agent'; hooks = @(@{ type = 'command'; command = 'node ~/.claude/hooks/serena-pre-delegation.js' }) }
)

$postToolUse = @(
    @{
        matcher = 'mcp__serena__find_symbol|mcp__serena__find_referencing_symbols|mcp__serena__get_symbols_overview|mcp__serena__find_file|mcp__serena__search_for_pattern|mcp__serena__list_dir'
        hooks   = @(@{ type = 'command'; command = 'node ~/.claude/hooks/serena-usage-tracker.js' })
    }
)

$sessionStart = @(
    @{ matcher = 'true'; hooks = @(@{ type = 'command'; command = 'node ~/.claude/hooks/serena-session-reset.js' }) }
)

foreach ($entry in $preToolUse) {
    if (-not (Has-HookCommand -Array $settings.hooks.PreToolUse -Command $entry.hooks[0].command)) {
        $settings.hooks.PreToolUse += ,$entry
    }
}

foreach ($entry in $postToolUse) {
    if (-not (Has-HookCommand -Array $settings.hooks.PostToolUse -Command $entry.hooks[0].command)) {
        $settings.hooks.PostToolUse += ,$entry
    }
}

foreach ($entry in $sessionStart) {
    if (-not (Has-HookCommand -Array $settings.hooks.SessionStart -Command $entry.hooks[0].command)) {
        $settings.hooks.SessionStart += ,$entry
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $Settings -Encoding UTF8
Write-Host '[3/4] settings.json updated (merged, old entries purged)'

# 4. Verify
Write-Host '[4/4] Verifying...'
$hookFiles = Get-ChildItem -Path $HooksDir -Filter 'serena-*.js' -ErrorAction SilentlyContinue
$hookCount = if ($hookFiles) { $hookFiles.Count } else { 0 }

$ruleOk = Test-Path (Join-Path $RulesDir 'lsp-first.md')
$stateOk = Test-Path $StateDir

# Detect Serena MCP registration in ~/.claude.json (best-effort)
$serenaOk = $false
$claudeConfig = Join-Path $env:USERPROFILE '.claude.json'
if (Test-Path $claudeConfig) {
    try {
        $cfg = Get-Content -Path $claudeConfig -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($cfg -and $cfg.mcpServers -and $cfg.mcpServers.ContainsKey('serena')) {
            $serenaOk = $true
        }
    } catch {}
}

Write-Host ''
Write-Host "  Hooks installed:  $hookCount/7"
Write-Host ('  Rule installed:   ' + $(if ($ruleOk) { 'yes' } else { 'no' }))
Write-Host ('  Serena MCP:       ' + $(if ($serenaOk) { 'yes' } else { 'no' }))
Write-Host ('  State directory:  ' + $(if ($stateOk) { 'yes' } else { 'no' }))
Write-Host ''

if ($hookCount -eq 7 -and $ruleOk) {
    Write-Host 'Done. Restart Claude Code to activate.' -ForegroundColor Green
    if (-not $serenaOk) {
        Write-Host 'NOTE: Serena MCP not detected. Install it with:' -ForegroundColor Yellow
        Write-Host '  claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant'
    }
} else {
    Write-Host 'WARNING: Some components missing. Check output above.' -ForegroundColor Yellow
    exit 1
}
