#!/bin/bash
# Uranus Install Script
#
# Thin wrapper around hiclaw-install.sh that sets Uranus-specific defaults:
#   - DockerHub registry: tingchaopavilion
#   - Manager runtime: hermes (with Web UI on port 6060)
#   - All images point to tingchaopavilion/uranus-* on DockerHub
#
# Usage:
#   bash install/uranus-install.sh                    # interactive
#   HICLAW_LLM_API_KEY=sk-xxx bash install/uranus-install.sh  # with API key
#
# Override any default by setting the env var before running:
#   HICLAW_DEFAULT_MODEL=gpt-4o bash install/uranus-install.sh
#
# For local models (Ollama / LM Studio):
#   HICLAW_LLM_PROVIDER=openai-compatible \
#   HICLAW_LLM_API_KEY=ollama \
#   HICLAW_OPENAI_BASE_URL=http://host.docker.internal:11434/v1 \
#   HICLAW_DEFAULT_MODEL=qwen3:27b \
#   bash install/uranus-install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Uranus Defaults ──────────────────────────────────────────────────────
# These can all be overridden by setting the env var before running.

# Registry: DockerHub tingchaopavilion (not Alibaba Cloud)
export HICLAW_REGISTRY="${HICLAW_REGISTRY:-docker.io/tingchaopavilion}"

# Version: match the git commit of this checkout
URANUS_VERSION="${URANUS_VERSION:-dev-$(git -C "${SCRIPT_DIR}/.." rev-parse --short HEAD 2>/dev/null || echo latest)}"
export HICLAW_VERSION="${HICLAW_VERSION:-${URANUS_VERSION}}"

# Manager runtime: Hermes (not openclaw/copaw)
export HICLAW_MANAGER_RUNTIME="${HICLAW_MANAGER_RUNTIME:-hermes}"

# Image overrides: point to tingchaopavilion/uranus-* naming convention
_REG="${HICLAW_REGISTRY}"
_VER="${HICLAW_VERSION}"
export HICLAW_INSTALL_EMBEDDED_IMAGE="${HICLAW_INSTALL_EMBEDDED_IMAGE:-${_REG}/uranus-embedded:${_VER}}"
export HICLAW_INSTALL_HERMES_WORKER_IMAGE="${HICLAW_INSTALL_HERMES_WORKER_IMAGE:-${_REG}/uranus-hermes-worker:${_VER}}"
export HICLAW_INSTALL_WORKER_IMAGE="${HICLAW_INSTALL_WORKER_IMAGE:-${_REG}/uranus-worker:${_VER}}"
export HICLAW_INSTALL_COPAW_WORKER_IMAGE="${HICLAW_INSTALL_COPAW_WORKER_IMAGE:-${_REG}/uranus-copaw-worker:${_VER}}"

# ── Print Config ─────────────────────────────────────────────────────────
echo "============================================"
echo "  Uranus Installer"
echo "  Registry:  ${_REG}"
echo "  Version:   ${_VER}"
echo "  Manager:   ${HICLAW_MANAGER_RUNTIME}"
echo "  Embedded:  ${HICLAW_INSTALL_EMBEDDED_IMAGE}"
echo "  Hermes:    ${HICLAW_INSTALL_HERMES_WORKER_IMAGE}"
echo "============================================"
echo ""

# ── Delegate to HiClaw installer ─────────────────────────────────────────
exec bash "${SCRIPT_DIR}/hiclaw-install.sh" "$@"
