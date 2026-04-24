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
