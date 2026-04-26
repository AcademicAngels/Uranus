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
    $repoRoot = Split-Path -Parent $ScriptDir
    $shortHash = & git -C $repoRoot rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $shortHash) {
        $env:HICLAW_VERSION = "dev-$shortHash"
    } else {
        $env:HICLAW_VERSION = "latest"
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
# Force UTF-8 so Chinese text in hiclaw-install.ps1 renders correctly on
# Windows PowerShell 5.1 (defaults to system locale, e.g., GBK).
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($PSVersionTable.PSVersion.Major -le 5) {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
}

& "$ScriptDir\hiclaw-install.ps1" @PassThrough
