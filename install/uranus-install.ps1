# Uranus Install Script (PowerShell)
#
# Thin wrapper around hiclaw-install.ps1 that sets Uranus-specific defaults:
#   - DockerHub registry: tingchaopavilion
#   - Manager runtime: hermes (with Web UI on port 6060)
#   - All images point to tingchaopavilion/uranus-* on DockerHub
#
# Usage:
#   .\install\uranus-install.ps1
#   $env:HICLAW_LLM_API_KEY = "sk-xxx"; .\install\uranus-install.ps1
#
# For local models (Ollama / LM Studio):
#   $env:HICLAW_LLM_PROVIDER = "openai-compatible"
#   $env:HICLAW_LLM_API_KEY = "ollama"
#   $env:HICLAW_OPENAI_BASE_URL = "http://host.docker.internal:11434/v1"
#   $env:HICLAW_DEFAULT_MODEL = "qwen3:27b"
#   .\install\uranus-install.ps1

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$PassThrough
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Uranus Defaults ──────────────────────────────────────────────────────

# Registry
if (-not $env:HICLAW_REGISTRY) {
    $env:HICLAW_REGISTRY = "docker.io/tingchaopavilion"
}

# Version
if (-not $env:HICLAW_VERSION) {
    Push-Location (Split-Path -Parent $ScriptDir)
    try {
        $shortHash = (& git rev-parse --short HEAD 2>$null).Trim()
        if ($shortHash) {
            $env:HICLAW_VERSION = "dev-$shortHash"
        } else {
            $env:HICLAW_VERSION = "latest"
        }
    } catch {
        $env:HICLAW_VERSION = "latest"
    } finally {
        Pop-Location
    }
}

# Manager runtime: Hermes
if (-not $env:HICLAW_MANAGER_RUNTIME) {
    $env:HICLAW_MANAGER_RUNTIME = "hermes"
}

# Image overrides
$reg = $env:HICLAW_REGISTRY
$ver = $env:HICLAW_VERSION

if (-not $env:HICLAW_INSTALL_EMBEDDED_IMAGE) {
    $env:HICLAW_INSTALL_EMBEDDED_IMAGE = "${reg}/uranus-embedded:${ver}"
}
if (-not $env:HICLAW_INSTALL_HERMES_WORKER_IMAGE) {
    $env:HICLAW_INSTALL_HERMES_WORKER_IMAGE = "${reg}/uranus-hermes-worker:${ver}"
}
if (-not $env:HICLAW_INSTALL_WORKER_IMAGE) {
    $env:HICLAW_INSTALL_WORKER_IMAGE = "${reg}/uranus-worker:${ver}"
}
if (-not $env:HICLAW_INSTALL_COPAW_WORKER_IMAGE) {
    $env:HICLAW_INSTALL_COPAW_WORKER_IMAGE = "${reg}/uranus-copaw-worker:${ver}"
}

# ── Print Config ─────────────────────────────────────────────────────────
Write-Host "============================================"
Write-Host "  Uranus Installer"
Write-Host "  Registry:  $reg"
Write-Host "  Version:   $ver"
Write-Host "  Manager:   $($env:HICLAW_MANAGER_RUNTIME)"
Write-Host "  Embedded:  $($env:HICLAW_INSTALL_EMBEDDED_IMAGE)"
Write-Host "  Hermes:    $($env:HICLAW_INSTALL_HERMES_WORKER_IMAGE)"
Write-Host "============================================"
Write-Host ""

# ── Delegate to HiClaw installer ─────────────────────────────────────────
# PowerShell 5.1 parses .ps1 files using the system default encoding (e.g.,
# GBK on Chinese Windows), which corrupts the Chinese strings in
# hiclaw-install.ps1 (UTF-8 without BOM).  Neither chcp nor
# [Console]::OutputEncoding changes the *parser* encoding.
#
# The fix (same approach as HiClaw's official install command): read the file
# as UTF-8 bytes, decode to string, then execute via ScriptBlock::Create().
$installerPath = Join-Path $ScriptDir "hiclaw-install.ps1"
$utf8Content = [System.IO.File]::ReadAllText($installerPath, [System.Text.Encoding]::UTF8)
& ([scriptblock]::Create($utf8Content)) @PassThrough
