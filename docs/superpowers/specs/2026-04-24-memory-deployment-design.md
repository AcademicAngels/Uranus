# Memory System Deployment Integration Design

**Date:** 2026-04-24
**Status:** Draft
**Scope:** Deployment chain fixes for the shared memory system (Obsidian vault + ReMe + mcpvault)

## Problem Statement

The shared memory system code is complete (9 commits on taiyi branch), but the deployment chain has 4 gaps that prevent the system from working in actual deployments:

1. Controller Pod missing `HICLAW_VAULT_PATH` and `HICLAW_EMBEDDING_MODEL` env vars
2. Install script not passing `HICLAW_VAULT_PATH` to controller container
3. Worker Dockerfiles missing mcpvault npm package
4. No deployment documentation for the memory system

## Constraints

- Target: individual developers / personal use
- Memory system defaults to enabled (no opt-in required)
- Follow existing deployment patterns (Helm values → deployment.yaml env → install script -e)
- Do not modify quickstart.md (memory is optional enhancement, not core onboarding)
- All docs in English (consistent with existing project docs)

## Design

### 1. Helm Chart Environment Variable Injection

**Files:**
- Modify: `helm/hiclaw/values.yaml`
- Modify: `helm/hiclaw/templates/controller/deployment.yaml`

Add memory configuration section to values.yaml:

```yaml
memory:
  vaultPath: "shared/vault"
  embeddingModel: "text-embedding-v4"
```

Inject into controller deployment.yaml env list:

```yaml
- name: HICLAW_VAULT_PATH
  value: {{ .Values.memory.vaultPath | default "shared/vault" | quote }}
- name: HICLAW_EMBEDDING_MODEL
  value: {{ .Values.memory.embeddingModel | default "" | quote }}
```

### 2. Install Script Update

**Files:**
- Modify: `install/hiclaw-install.sh`

Add `HICLAW_VAULT_PATH` to controller container env args (following existing `HICLAW_EMBEDDING_MODEL` pattern):

```bash
_ctrl_env_args+=(-e "HICLAW_VAULT_PATH=${HICLAW_VAULT_PATH:-shared/vault}")
```

No interactive prompt — default value is sufficient for personal use. Users override via environment variable if needed.

Add documentation comment at script header for the new variable.

### 3. Dockerfile mcpvault Installation

**Files:**
- Modify: `copaw/Dockerfile`
- Modify: `hermes/Dockerfile`

Add mcpvault to existing npm install lines:

```dockerfile
RUN npm install -g mcporter skills @nacos-group/cli mcpvault
```

No entrypoint changes — mcpvault is started on-demand by Manager via MCP registration skill, not auto-started in container.

### 4. Deployment Documentation

**Files:**
- Create: `docs/memory-deployment-guide.md`

Sections:
1. Overview — what the shared memory system is, what it solves
2. Prerequisites — HiClaw deployed, Obsidian (optional)
3. Docker deployment — env var config, defaults already enabled
4. K8s/Helm deployment — memory.* values.yaml entries
5. Obsidian vault sync — mc mirror --watch setup
6. mcpvault MCP Server — Manager skill registration
7. Local GPU embedding — Ollama setup for 4070Ti environments
8. Verification steps — how to confirm memory system works
9. Troubleshooting — common issues

## What This Design Does NOT Include

- CRD memory/vault fields (per-agent config not needed for personal use)
- Sync script vault-specific logic (default path `shared/vault` already under `shared/` sync scope)
- Makefile memory targets (not needed for deployment)
- Changes to quickstart.md (memory is optional enhancement)
