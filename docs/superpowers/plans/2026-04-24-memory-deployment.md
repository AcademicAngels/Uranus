# Memory System Deployment Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the shared memory system (Obsidian vault + ReMe + mcpvault) through the full deployment chain so it works out-of-the-box for personal users.

**Architecture:** Four deployment chain fixes: Helm chart env var injection, install script env passthrough, Dockerfile mcpvault pre-install, and a deployment guide document. All follow existing patterns — no new deployment mechanisms.

**Tech Stack:** Helm/YAML (chart), Bash (install script), Docker (Dockerfile), Markdown (docs)

**Spec:** `docs/superpowers/specs/2026-04-24-memory-deployment-design.md`

---

## File Structure

### Modified Files
| File | Change |
|---|---|
| `helm/hiclaw/values.yaml:190` | Add `memory:` config section after `controller.env` |
| `helm/hiclaw/templates/controller/deployment.yaml:168` | Inject HICLAW_VAULT_PATH and HICLAW_EMBEDDING_MODEL env vars |
| `install/hiclaw-install.sh:47,2333,2749` | Add HICLAW_VAULT_PATH to header docs, env file, and controller args |
| `copaw/Dockerfile:64` | Add mcpvault to npm install |
| `hermes/Dockerfile:79` | Add mcpvault to npm install |

### New Files
| File | Responsibility |
|---|---|
| `docs/memory-deployment-guide.md` | Deployment guide for the shared memory system |

---

### Task 1: Helm Chart Environment Variable Injection

**Files:**
- Modify: `helm/hiclaw/values.yaml:190`
- Modify: `helm/hiclaw/templates/controller/deployment.yaml:168`

- [ ] **Step 1: Add memory config section to values.yaml**

In `helm/hiclaw/values.yaml`, after line 191 (`timezone: "Asia/Shanghai"`), add:

```yaml
  # ── Shared Memory System ──────────────────────────────────────────────────
  # Obsidian vault path in MinIO for shared agent knowledge.
  # Set embeddingModel to "" to disable semantic memory search.
  memory:
    vaultPath: "shared/vault"
    embeddingModel: "text-embedding-v4"
```

The result should look like:

```yaml
  env: {}
  timezone: "Asia/Shanghai"
  # ── Shared Memory System ──────────────────────────────────────────────────
  # Obsidian vault path in MinIO for shared agent knowledge.
  # Set embeddingModel to "" to disable semantic memory search.
  memory:
    vaultPath: "shared/vault"
    embeddingModel: "text-embedding-v4"

# ── Manager Agent (CRD-driven) ────────────────────────────────────────────
```

- [ ] **Step 2: Inject env vars into controller deployment.yaml**

In `helm/hiclaw/templates/controller/deployment.yaml`, after line 168 (`{{- end }}` closing the CMS metrics block) and before line 169 (`{{- range $k, $v := .Values.controller.env }}`), insert:

```yaml
            {{- if .Values.controller.memory }}
            {{- with .Values.controller.memory.vaultPath }}
            - name: HICLAW_VAULT_PATH
              value: {{ . | quote }}
            {{- end }}
            {{- with .Values.controller.memory.embeddingModel }}
            - name: HICLAW_EMBEDDING_MODEL
              value: {{ . | quote }}
            {{- end }}
            {{- end }}
```

- [ ] **Step 3: Verify Helm template renders correctly**

Run: `cd helm && helm template hiclaw ./hiclaw 2>&1 | grep -A1 'HICLAW_VAULT_PATH\|HICLAW_EMBEDDING_MODEL'`

Expected output:
```
            - name: HICLAW_VAULT_PATH
              value: "shared/vault"
            - name: HICLAW_EMBEDDING_MODEL
              value: "text-embedding-v4"
```

- [ ] **Step 4: Verify template renders without memory config (backwards compat)**

Run: `cd helm && helm template hiclaw ./hiclaw --set controller.memory=null 2>&1 | grep 'HICLAW_VAULT_PATH' | wc -l`

Expected: `0` (no HICLAW_VAULT_PATH when memory config is null)

- [ ] **Step 5: Commit**

```bash
git add helm/hiclaw/values.yaml helm/hiclaw/templates/controller/deployment.yaml
git commit -m "feat(helm): add memory system config (vaultPath, embeddingModel) to controller"
```

---

### Task 2: Install Script Update

**Files:**
- Modify: `install/hiclaw-install.sh:47,1676,2333,2749`

- [ ] **Step 1: Add HICLAW_VAULT_PATH to script header documentation**

In `install/hiclaw-install.sh`, after line 47 (`HICLAW_WORKER_IDLE_TIMEOUT`), add:

```bash
#   HICLAW_VAULT_PATH         Shared vault path in MinIO (default: shared/vault)
```

- [ ] **Step 2: Add HICLAW_VAULT_PATH default in non-interactive mode**

In `install/hiclaw-install.sh`, after line 1676 (`HICLAW_EMBEDDING_MODEL="${HICLAW_EMBEDDING_MODEL-text-embedding-v4}"`), add:

```bash
        HICLAW_VAULT_PATH="${HICLAW_VAULT_PATH-shared/vault}"
```

- [ ] **Step 3: Add HICLAW_VAULT_PATH to env file generation**

In `install/hiclaw-install.sh`, after line 2333 (`HICLAW_EMBEDDING_MODEL=${HICLAW_EMBEDDING_MODEL}`), add:

```bash

# Shared vault path (default: shared/vault)
HICLAW_VAULT_PATH=${HICLAW_VAULT_PATH:-shared/vault}
```

- [ ] **Step 4: Add HICLAW_VAULT_PATH to controller container env args**

In `install/hiclaw-install.sh`, after line 2750 (`fi` closing the HICLAW_EMBEDDING_MODEL block), add:

```bash

        # Optional: shared vault path
        if [ -n "${HICLAW_VAULT_PATH:-}" ]; then
            _ctrl_env_args+=(-e "HICLAW_VAULT_PATH=${HICLAW_VAULT_PATH}")
        fi
```

- [ ] **Step 5: Verify the script parses correctly**

Run: `bash -n install/hiclaw-install.sh && echo "Syntax OK"`

Expected: `Syntax OK`

- [ ] **Step 6: Verify HICLAW_VAULT_PATH appears in all three locations**

Run: `grep -n 'HICLAW_VAULT_PATH' install/hiclaw-install.sh`

Expected: At least 4 matches (header doc, non-interactive default, env file, ctrl_env_args)

- [ ] **Step 7: Commit**

```bash
git add install/hiclaw-install.sh
git commit -m "feat(install): pass HICLAW_VAULT_PATH to controller container"
```

---

### Task 3: Dockerfile mcpvault Installation

**Files:**
- Modify: `copaw/Dockerfile:64`
- Modify: `hermes/Dockerfile:79`

- [ ] **Step 1: Add mcpvault to copaw Dockerfile**

In `copaw/Dockerfile`, change line 64 from:

```dockerfile
    npm install -g mcporter skills @nacos-group/cli && \
```

To:

```dockerfile
    npm install -g mcporter skills @nacos-group/cli mcpvault && \
```

- [ ] **Step 2: Add mcpvault to hermes Dockerfile**

In `hermes/Dockerfile`, change line 79 from:

```dockerfile
    npm install -g mcporter skills @nacos-group/cli && \
```

To:

```dockerfile
    npm install -g mcporter skills @nacos-group/cli mcpvault && \
```

- [ ] **Step 3: Commit**

```bash
git add copaw/Dockerfile hermes/Dockerfile
git commit -m "feat(docker): pre-install mcpvault in copaw and hermes worker images"
```

---

### Task 4: Deployment Documentation

**Files:**
- Create: `docs/memory-deployment-guide.md`

- [ ] **Step 1: Write the deployment guide**

Create `docs/memory-deployment-guide.md` with the following content:

```markdown
# Shared Memory System Deployment Guide

The shared memory system enables semantic knowledge sharing across HiClaw agents (Hermes, OpenClaw, QwenClaw) using ReMe for memory management and an optional Obsidian vault for human-readable knowledge exchange.

## Prerequisites

- HiClaw installed and running (Docker or Kubernetes)
- (Optional) [Obsidian](https://obsidian.md/) for viewing/editing agent knowledge

## Default Behavior

The memory system is **enabled by default** in new deployments:

| Setting | Default | Effect |
|---------|---------|--------|
| `HICLAW_VAULT_PATH` | `shared/vault` | Agents index this MinIO path for shared knowledge |
| `HICLAW_EMBEDDING_MODEL` | `text-embedding-v4` | Semantic search via AI Gateway embedding |

No configuration is required for basic operation.

## Docker Deployment

Environment variables are set during installation. To customize:

```bash
# Override vault path (rarely needed)
export HICLAW_VAULT_PATH="shared/vault"

# Use a different embedding model
export HICLAW_EMBEDDING_MODEL="text-embedding-v4"

# Disable semantic search (keyword-only fallback)
export HICLAW_EMBEDDING_MODEL=""

# Then run the installer
bash <(curl -sSL https://higress.ai/hiclaw/install.sh)
```

These values are saved to `hiclaw-manager.env` and persist across restarts.

## Kubernetes / Helm Deployment

Configure via `values.yaml`:

```yaml
controller:
  memory:
    vaultPath: "shared/vault"           # MinIO path for shared vault
    embeddingModel: "text-embedding-v4" # empty string = disabled
```

Or via `--set` flags:

```bash
helm install hiclaw higress.io/hiclaw \
  --set controller.memory.vaultPath="shared/vault" \
  --set controller.memory.embeddingModel="text-embedding-v4"
```

## Obsidian Vault Sync (Optional)

To use Obsidian as a human-readable interface for agent knowledge:

### 1. Initialize the vault

```bash
# Copy the scaffold to your Obsidian vault location
cp -r shared/vault-scaffold/ ~/obsidian-hiclaw-vault/
```

### 2. Open in Obsidian

Open `~/obsidian-hiclaw-vault/` as an Obsidian vault.

### 3. Set up bidirectional sync

```bash
# One-time push
mc mirror ~/obsidian-hiclaw-vault/ minio/hiclaw-storage/shared/vault/

# Watch for changes (run in background)
mc mirror --watch ~/obsidian-hiclaw-vault/ minio/hiclaw-storage/shared/vault/
```

### Directory structure

| Directory | Owner | Purpose |
|-----------|-------|---------|
| `knowledge/` | You | Your notes, references, decisions |
| `agent-shared/` | Agents | Cross-agent task insights and tool guides |
| `agent-private/` | Per-agent | Individual agent memory files |

## mcpvault MCP Server (Optional)

mcpvault provides Obsidian-aware tools (backlinks, tags, search) to agents via MCP. It reads markdown files directly — Obsidian does not need to be running.

### Start mcpvault

```bash
# mcpvault is pre-installed in worker containers
mcpvault --vault ~/hiclaw-fs/shared/vault --port 3200 &
```

### Register with HiClaw

From the Manager agent (via Matrix chat or CLI):

> Register the Obsidian vault MCP server at http://localhost:3200/mcp

Or manually:

```bash
bash skills/mcp-server-management/scripts/setup-mcp-proxy.sh \
    obsidian-vault http://localhost:3200/mcp sse
```

All workers automatically receive access on next sync cycle.

## Local GPU Embedding (Production)

For environments with a GPU (e.g., NVIDIA 4070Ti), run embeddings locally:

### 1. Serve an embedding model

```bash
ollama pull bge-m3
ollama serve
```

### 2. Configure HiClaw

```bash
# Docker
export HICLAW_EMBEDDING_MODEL=bge-m3
export HICLAW_AI_GATEWAY_URL=http://localhost:11434

# Kubernetes
helm upgrade hiclaw higress.io/hiclaw \
  --set controller.memory.embeddingModel=bge-m3
```

Expected VRAM usage: ~1-2 GB for bge-m3.

## Verification

### Check vault path is configured

```bash
# Docker: inspect controller env
docker inspect hiclaw-controller | grep HICLAW_VAULT_PATH

# Kubernetes: check pod env
kubectl exec -n hiclaw-system deploy/hiclaw-controller -- env | grep HICLAW_VAULT_PATH
```

Expected: `HICLAW_VAULT_PATH=shared/vault`

### Check agent config includes vault

```bash
# Check MinIO for generated agent config
mc cat minio/hiclaw-storage/agents/<worker-name>/config/openclaw.json | jq '.agents.defaults.memorySearch'
```

Expected: JSON with `vaultPath`, `model`, and `remote` fields.

### Check mcpvault is available (if installed)

```bash
mcpvault --version
```

## Troubleshooting

### Agents don't have memorySearch in their config

**Cause:** Controller missing `HICLAW_EMBEDDING_MODEL` env var.

**Fix:** Verify the env var is set:
```bash
docker inspect hiclaw-controller | grep HICLAW_EMBEDDING_MODEL
```
If empty, re-run the installer or set it manually and restart.

### Vault files not syncing to agents

**Cause:** Vault path not under `shared/` prefix (which is auto-synced).

**Fix:** Use the default `shared/vault` path, or ensure your custom path starts with `shared/`.

### Embedding search returns no results

**Cause:** Embedding model not accessible via AI Gateway.

**Fix:** Test connectivity:
```bash
curl -X POST http://aigw-local.hiclaw.io:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "text-embedding-v4", "input": "test"}'
```

### mcpvault command not found

**Cause:** Using an older container image without mcpvault pre-installed.

**Fix:** Update to the latest image, or install manually:
```bash
npm install -g mcpvault
```
```

- [ ] **Step 2: Commit**

```bash
git add docs/memory-deployment-guide.md
git commit -m "docs: add shared memory system deployment guide"
```

---

## Summary

| Task | Description | Files Changed |
|---|---|---|
| 1 | Helm chart env var injection | values.yaml, deployment.yaml |
| 2 | Install script vault path | hiclaw-install.sh |
| 3 | Dockerfile mcpvault install | copaw/Dockerfile, hermes/Dockerfile |
| 4 | Deployment documentation | memory-deployment-guide.md |
