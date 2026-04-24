# Shared Memory System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable semantic-search-capable shared memory across Hermes/OpenClaw/QwenClaw agents using ReMe (embedded) + Obsidian MCP (mcpvault), with MinIO as persistence layer.

**Architecture:** Two-layer hybrid — ReMe manages per-agent memory lifecycle (compression, retrieval, structured extraction) with LocalVectorStore for semantic search; mcpvault provides Obsidian knowledge base queries (backlinks, tags, full-text) via MCP. MinIO syncs everything; Obsidian is the human-readable interface.

**Tech Stack:** Python (CoPaw/Hermes workers), Go (hiclaw-controller), ReMe (reme-ai pip package), mcpvault (MCP server), MinIO (object storage), Higress (AI Gateway for embeddings)

**Spec:** `docs/superpowers/specs/2026-04-24-shared-memory-system-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|---|---|
| `shared/vault-scaffold/knowledge/.gitkeep` | Seed directory for human knowledge |
| `shared/vault-scaffold/agent-shared/task-insights.md` | Seed file for cross-agent task memory |
| `shared/vault-scaffold/agent-shared/tool-guide.md` | Seed file for cross-agent tool memory |
| `shared/vault-scaffold/agent-shared/daily/.gitkeep` | Seed directory for daily logs |
| `shared/vault-scaffold/README.md` | Setup instructions for Obsidian vault |
| `manager/agent/skills/mcp-server-management/references/mcp-obsidian-vault.yaml` | mcpvault MCP server template |
| `manager/agent/skills/memory-aggregation/SKILL.md` | Manager skill for cross-agent memory aggregation |
| `manager/agent/skills/memory-aggregation/scripts/aggregate-memories.sh` | Aggregation script |
| `copaw/tests/test_vault_sync.py` | Tests for vault path sync behavior |
| `hermes/tests/test_bridge_embedding.py` | Tests for Hermes embedding config |

### Modified Files
| File | Change |
|---|---|
| `hermes/src/hermes_worker/bridge.py` | Add embedding config passthrough to Hermes config |
| `hiclaw-controller/internal/agentconfig/generator.go` | Add `vaultPath` to memorySearch config |
| `hiclaw-controller/internal/agentconfig/generator_test.go` | Test vault path in memorySearch |
| `hiclaw-controller/internal/agentconfig/types.go` | Add `VaultPath` field to Config |
| `hiclaw-controller/internal/config/config.go` | Load `HICLAW_VAULT_PATH` env var |
| `shared/lib/hiclaw-env.sh` | Export `HICLAW_VAULT_PATH` default |
| `copaw/src/copaw_worker/bridge.py` | Pass vault_path from memorySearch to agent config |

---

## Phase 1: Enable ReMe + Shared Vault via MinIO

### Task 1: Obsidian Vault Scaffold

**Files:**
- Create: `shared/vault-scaffold/README.md`
- Create: `shared/vault-scaffold/knowledge/.gitkeep`
- Create: `shared/vault-scaffold/agent-shared/task-insights.md`
- Create: `shared/vault-scaffold/agent-shared/tool-guide.md`
- Create: `shared/vault-scaffold/agent-shared/daily/.gitkeep`

- [ ] **Step 1: Create vault scaffold directory and README**

```bash
mkdir -p shared/vault-scaffold/knowledge
mkdir -p shared/vault-scaffold/agent-shared/daily
```

```markdown
# shared/vault-scaffold/README.md

# Obsidian Vault Setup

This directory contains the scaffold for the shared Obsidian vault used by HiClaw agents.

## Setup

1. Copy this directory to your Obsidian vault location:
   ```bash
   cp -r shared/vault-scaffold/ ~/obsidian-hiclaw-vault/
   ```

2. Open `~/obsidian-hiclaw-vault/` as an Obsidian vault.

3. Set up bidirectional sync with MinIO:
   ```bash
   # Push vault to MinIO (run once)
   mc mirror ~/obsidian-hiclaw-vault/ minio/hiclaw-storage/shared/vault/

   # Watch for changes (run in background)
   mc mirror --watch ~/obsidian-hiclaw-vault/ minio/hiclaw-storage/shared/vault/
   ```

## Directory Structure

- `knowledge/` — Your notes, references, decisions (you write, agents read)
- `agent-shared/` — Agent insights and daily logs (agents write, you review)
- `agent-private/` — Per-agent memory files (created automatically by agents)
```

- [ ] **Step 2: Create seed files for agent-shared directory**

```markdown
# shared/vault-scaffold/agent-shared/task-insights.md

# Task Insights

Aggregated task execution patterns from all agents. Updated daily by Hermes (Manager).

## Success Patterns

_No entries yet. Agents will add entries as they complete tasks._

## Failure Patterns

_No entries yet._

## Comparative Insights

_No entries yet._
```

```markdown
# shared/vault-scaffold/agent-shared/tool-guide.md

# Tool Usage Guide

Aggregated tool usage experience from all agents. Updated daily by Hermes (Manager).

## Tool Selection

_No entries yet. Agents will add entries as they discover tool usage patterns._

## Parameter Tips

_No entries yet._
```

- [ ] **Step 3: Create .gitkeep files**

```bash
touch shared/vault-scaffold/knowledge/.gitkeep
touch shared/vault-scaffold/agent-shared/daily/.gitkeep
```

- [ ] **Step 4: Commit**

```bash
git add shared/vault-scaffold/
git commit -m "feat(memory): add Obsidian vault scaffold with seed files"
```

---

### Task 2: Add Vault Path to Controller Config

**Files:**
- Modify: `hiclaw-controller/internal/agentconfig/types.go:4-28`
- Modify: `hiclaw-controller/internal/config/config.go:207-352`
- Modify: `shared/lib/hiclaw-env.sh:47-51`

- [ ] **Step 1: Write failing test for vault path in config**

Add to `hiclaw-controller/internal/agentconfig/generator_test.go` after the existing `TestGenerateOpenClawConfig_WithEmbedding` test (line 182):

```go
func TestGenerateOpenClawConfig_WithVaultPath(t *testing.T) {
	g := NewGenerator(Config{
		MatrixDomain:   "hiclaw.io",
		AIGatewayURL:   "http://aigw:8080",
		EmbeddingModel: "text-embedding-v4",
		VaultPath:      "shared/vault",
	})

	data, err := g.GenerateOpenClawConfig(WorkerConfigRequest{
		WorkerName: "alice",
		GatewayKey: "key123",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var config map[string]interface{}
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}

	agents := config["agents"].(map[string]interface{})
	defaults := agents["defaults"].(map[string]interface{})
	ms := defaults["memorySearch"].(map[string]interface{})

	vaultPath, ok := ms["vaultPath"].(string)
	if !ok || vaultPath != "shared/vault" {
		t.Errorf("vaultPath = %q, want %q", vaultPath, "shared/vault")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd hiclaw-controller && go test ./internal/agentconfig/ -run TestGenerateOpenClawConfig_WithVaultPath -v`
Expected: FAIL — `Config` struct has no `VaultPath` field

- [ ] **Step 3: Add VaultPath to Config struct**

In `hiclaw-controller/internal/agentconfig/types.go`, add to the `Config` struct after `EmbeddingModel`:

```go
type Config struct {
	MatrixDomain     string
	MatrixServerURL  string
	AIGatewayURL     string
	AdminUser        string
	DefaultModel     string
	EmbeddingModel   string
	VaultPath        string
	Runtime          string
	// ... rest unchanged
```

- [ ] **Step 4: Inject vaultPath into memorySearch in generator.go**

In `hiclaw-controller/internal/agentconfig/generator.go`, modify the embedding model block (lines 164-176). Replace:

```go
if g.config.EmbeddingModel != "" {
	agents := config["agents"].(map[string]interface{})
	defaults := agents["defaults"].(map[string]interface{})
	defaults["memorySearch"] = map[string]interface{}{
		"provider": "openai",
		"model":    g.config.EmbeddingModel,
		"remote": map[string]interface{}{
			"baseUrl": aiGatewayURL + "/v1",
			"apiKey":  req.GatewayKey,
		},
	}
}
```

With:

```go
if g.config.EmbeddingModel != "" {
	agents := config["agents"].(map[string]interface{})
	defaults := agents["defaults"].(map[string]interface{})
	ms := map[string]interface{}{
		"provider": "openai",
		"model":    g.config.EmbeddingModel,
		"remote": map[string]interface{}{
			"baseUrl": aiGatewayURL + "/v1",
			"apiKey":  req.GatewayKey,
		},
	}
	if g.config.VaultPath != "" {
		ms["vaultPath"] = g.config.VaultPath
	}
	defaults["memorySearch"] = ms
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd hiclaw-controller && go test ./internal/agentconfig/ -run TestGenerateOpenClawConfig_WithVaultPath -v`
Expected: PASS

- [ ] **Step 6: Run all existing tests to check for regressions**

Run: `cd hiclaw-controller && go test ./internal/agentconfig/ -v`
Expected: All tests PASS

- [ ] **Step 7: Add HICLAW_VAULT_PATH to config.go**

In `hiclaw-controller/internal/config/config.go`, add to the Config struct (after `EmbeddingModel`):

```go
VaultPath      string
```

In `LoadConfig()`, add after the `EmbeddingModel` line:

```go
VaultPath:      os.Getenv("HICLAW_VAULT_PATH"),
```

In `AgentConfig()` method, add after the `EmbeddingModel` field:

```go
VaultPath:      c.VaultPath,
```

- [ ] **Step 8: Add HICLAW_VAULT_PATH to hiclaw-env.sh**

In `shared/lib/hiclaw-env.sh`, after line 51 (`export HICLAW_EMBEDDING_MODEL`), add:

```bash
HICLAW_VAULT_PATH="${HICLAW_VAULT_PATH-shared/vault}"
export HICLAW_VAULT_PATH
```

- [ ] **Step 9: Commit**

```bash
git add hiclaw-controller/internal/agentconfig/types.go \
       hiclaw-controller/internal/agentconfig/generator.go \
       hiclaw-controller/internal/agentconfig/generator_test.go \
       hiclaw-controller/internal/config/config.go \
       shared/lib/hiclaw-env.sh
git commit -m "feat(controller): add vaultPath to memorySearch config for shared knowledge"
```

---

### Task 3: Pass Vault Path Through CoPaw Bridge

**Files:**
- Modify: `copaw/src/copaw_worker/bridge.py:268-308`
- Test: `copaw/tests/test_bridge.py`

- [ ] **Step 1: Write failing test for vault_path in embedding config**

Add to `copaw/tests/test_bridge.py` after the existing `test_embedding_config_custom_dimensions` test:

```python
def test_embedding_config_includes_vault_path(monkeypatch):
    monkeypatch.setattr(bridge_module, "_is_in_container", lambda: True)
    cfg = _make_openclaw_cfg()
    cfg["agents"]["defaults"]["memorySearch"]["vaultPath"] = "shared/vault"
    agent = _bridge_and_read_agent(cfg)
    emb = agent["running"]["embedding_config"]
    assert emb["vault_path"] == "shared/vault"


def test_embedding_config_omits_vault_path_when_absent(monkeypatch):
    monkeypatch.setattr(bridge_module, "_is_in_container", lambda: True)
    cfg = _make_openclaw_cfg()
    agent = _bridge_and_read_agent(cfg)
    emb = agent["running"]["embedding_config"]
    assert "vault_path" not in emb
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd copaw && python -m pytest tests/test_bridge.py::test_embedding_config_includes_vault_path -v`
Expected: FAIL — `vault_path` not in embedding_config

- [ ] **Step 3: Add vault_path to _resolve_embedding_config**

In `copaw/src/copaw_worker/bridge.py`, in `_resolve_embedding_config()`, add before the `return` statement:

```python
    result = {
        "backend": "openai",
        "api_key": api_key,
        "base_url": base_url,
        "model_name": model,
        "dimensions": dimensions,
        "enable_cache": True,
        "use_dimensions": False,
    }

    vault_path = memory_search.get("vaultPath", "")
    if vault_path:
        result["vault_path"] = vault_path

    return result
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd copaw && python -m pytest tests/test_bridge.py -v`
Expected: All tests PASS including the two new ones

- [ ] **Step 5: Commit**

```bash
git add copaw/src/copaw_worker/bridge.py copaw/tests/test_bridge.py
git commit -m "feat(copaw): pass vaultPath through embedding config for shared vault indexing"
```

---

### Task 4: Add Embedding Config to Hermes Bridge

**Files:**
- Modify: `hermes/src/hermes_worker/bridge.py`
- Create: `hermes/tests/test_bridge_embedding.py`

The Hermes bridge currently does NOT pass embedding/memorySearch config to Hermes. This task adds it.

- [ ] **Step 1: Write failing test for embedding config in Hermes**

Create `hermes/tests/test_bridge_embedding.py`:

```python
"""Tests for embedding config passthrough in Hermes bridge."""

import tempfile
from pathlib import Path

import yaml

from hermes_worker import bridge as bridge_module
from hermes_worker.bridge import bridge_openclaw_to_hermes


def _make_openclaw_cfg_with_embedding() -> dict:
    return {
        "channels": {
            "matrix": {
                "homeserver": "http://matrix:6167",
                "accessToken": "tok",
                "userId": "@alice:hiclaw.io",
            }
        },
        "models": {
            "providers": {
                "gw": {
                    "baseUrl": "http://aigw:8080/v1",
                    "apiKey": "key123",
                    "models": [{"id": "qwen3.5-plus", "input": ["text"]}],
                }
            }
        },
        "agents": {
            "defaults": {
                "model": {"primary": "gw/qwen3.5-plus"},
                "memorySearch": {
                    "provider": "openai",
                    "model": "text-embedding-v4",
                    "vaultPath": "shared/vault",
                    "remote": {
                        "baseUrl": "http://aigw:8080/v1",
                        "apiKey": "key123",
                    },
                },
            }
        },
    }


def _bridge_and_read(openclaw_cfg: dict) -> dict:
    with tempfile.TemporaryDirectory() as tmpdir:
        hermes_home = Path(tmpdir) / ".hermes"
        hermes_home.mkdir(parents=True, exist_ok=True)
        bridge_openclaw_to_hermes(openclaw_cfg, hermes_home)
        return yaml.safe_load((hermes_home / "config.yaml").read_text())


def test_embedding_config_written_to_hermes(monkeypatch):
    monkeypatch.setattr(bridge_module, "_is_in_container", lambda: True)
    cfg = _make_openclaw_cfg_with_embedding()
    config = _bridge_and_read(cfg)
    assert "memory" in config
    mem = config["memory"]
    assert mem["memory_enabled"] is True
    assert mem["embedding_model"] == "text-embedding-v4"
    assert mem["embedding_base_url"] == "http://aigw:8080/v1"
    assert mem["vault_path"] == "shared/vault"


def test_embedding_config_absent_when_no_memory_search(monkeypatch):
    monkeypatch.setattr(bridge_module, "_is_in_container", lambda: True)
    cfg = _make_openclaw_cfg_with_embedding()
    del cfg["agents"]["defaults"]["memorySearch"]
    config = _bridge_and_read(cfg)
    mem = config.get("memory", {})
    assert "embedding_model" not in mem
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd hermes && python -m pytest tests/test_bridge_embedding.py -v`
Expected: FAIL — `memory` section missing embedding fields

- [ ] **Step 3: Add embedding config to Hermes bridge**

In `hermes/src/hermes_worker/bridge.py`, in the `bridge_openclaw_to_hermes()` function, after the memory defaults block (`existing_yaml.setdefault("memory", {}).setdefault("memory_enabled", True)`), add:

```python
    # Bridge embedding/memory-search config from openclaw.json
    memory_search = (
        openclaw_cfg.get("agents", {})
        .get("defaults", {})
        .get("memorySearch", {})
    )
    if memory_search:
        remote = memory_search.get("remote", {})
        base_url = _port_remap(remote.get("baseUrl", ""), in_container)
        model = memory_search.get("model", "")
        if base_url and model:
            mem_block = existing_yaml.setdefault("memory", {})
            mem_block["memory_enabled"] = True
            mem_block["embedding_model"] = model
            mem_block["embedding_base_url"] = base_url
            mem_block["embedding_api_key"] = remote.get("apiKey", "")
            vault_path = memory_search.get("vaultPath", "")
            if vault_path:
                mem_block["vault_path"] = vault_path
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd hermes && python -m pytest tests/test_bridge_embedding.py -v`
Expected: All tests PASS

- [ ] **Step 5: Run all existing Hermes tests for regressions**

Run: `cd hermes && python -m pytest tests/ -v`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add hermes/src/hermes_worker/bridge.py hermes/tests/test_bridge_embedding.py
git commit -m "feat(hermes): bridge embedding and vault config from openclaw.json"
```

---

### Task 5: Manager Memory Aggregation Skill

**Files:**
- Create: `manager/agent/skills/memory-aggregation/SKILL.md`
- Create: `manager/agent/skills/memory-aggregation/scripts/aggregate-memories.sh`

- [ ] **Step 1: Create skill manifest**

```markdown
# manager/agent/skills/memory-aggregation/SKILL.md
---
name: memory-aggregation
description: >-
  Aggregate task and tool memory insights from all workers into the shared
  vault.  Run daily (or on-demand) to keep agent-shared/task-insights.md
  and agent-shared/tool-guide.md up to date.
---

# Memory Aggregation

Pull each worker's `memory/task-insights/` and `memory/tool-guide/` from
MinIO, deduplicate entries, and merge into the shared vault at
`shared/vault/agent-shared/`.

## When to Use

- Daily idle-time aggregation (recommended: run during heartbeat check)
- After a worker completes a complex multi-step task
- When admin requests a knowledge sync

## Usage

```bash
bash skills/memory-aggregation/scripts/aggregate-memories.sh
```

The script:
1. Lists all workers from `~/workers-registry.json`
2. Pulls `agents/{worker}/memory/task-insights/` from MinIO
3. Pulls `agents/{worker}/memory/tool-guide/` from MinIO
4. Merges into `shared/vault/agent-shared/task-insights.md` and `tool-guide.md`
5. Pushes updated files to MinIO `shared/vault/agent-shared/`
6. Workers pick up changes on next sync cycle (≤30s)

## Notes

- Entries are deduplicated by content hash (first 80 chars)
- Existing manual edits in the target files are preserved
- The script is idempotent — safe to run multiple times
```

- [ ] **Step 2: Create aggregation script**

```bash
#!/usr/bin/env bash
# manager/agent/skills/memory-aggregation/scripts/aggregate-memories.sh
#
# Aggregate worker task/tool memory into shared vault.
# Reads workers-registry.json, pulls per-worker memory files from MinIO,
# merges into shared/vault/agent-shared/.

set -euo pipefail

REGISTRY="${HOME}/workers-registry.json"
SHARED_DIR="${HOME}/shared/vault/agent-shared"
MC_ALIAS="${HICLAW_MC_ALIAS:-hiclaw}"
BUCKET="${HICLAW_FS_BUCKET:-hiclaw-storage}"
PREFIX="${HICLAW_STORAGE_PREFIX:-hiclaw/hiclaw-storage}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if [ ! -f "$REGISTRY" ]; then
    echo "No workers-registry.json found, nothing to aggregate."
    exit 0
fi

mkdir -p "$SHARED_DIR/daily"

WORKERS=$(jq -r 'keys[]' "$REGISTRY" 2>/dev/null || echo "")
if [ -z "$WORKERS" ]; then
    echo "No workers registered."
    exit 0
fi

TASK_FILE="$SHARED_DIR/task-insights.md"
TOOL_FILE="$SHARED_DIR/tool-guide.md"
TODAY=$(date +%Y-%m-%d)

# Collect entries from all workers
TASK_ENTRIES=""
TOOL_ENTRIES=""

for worker in $WORKERS; do
    WORKER_MEM="${MC_ALIAS}/${BUCKET}/agents/${worker}/memory"

    # Pull task insights
    mc cp --quiet --recursive "${WORKER_MEM}/task-insights/" "$TMPDIR/${worker}/task/" 2>/dev/null || true

    # Pull tool guide entries
    mc cp --quiet --recursive "${WORKER_MEM}/tool-guide/" "$TMPDIR/${worker}/tool/" 2>/dev/null || true

    # Collect task entries
    if [ -d "$TMPDIR/${worker}/task" ]; then
        for f in "$TMPDIR/${worker}/task/"*.md; do
            [ -f "$f" ] || continue
            ENTRY=$(cat "$f")
            HASH=$(echo "$ENTRY" | head -c 80 | md5sum | cut -d' ' -f1)
            if ! grep -qF "$HASH" "$TASK_FILE" 2>/dev/null; then
                TASK_ENTRIES="${TASK_ENTRIES}
<!-- hash:${HASH} worker:${worker} date:${TODAY} -->
${ENTRY}
"
            fi
        done
    fi

    # Collect tool entries
    if [ -d "$TMPDIR/${worker}/tool" ]; then
        for f in "$TMPDIR/${worker}/tool/"*.md; do
            [ -f "$f" ] || continue
            ENTRY=$(cat "$f")
            HASH=$(echo "$ENTRY" | head -c 80 | md5sum | cut -d' ' -f1)
            if ! grep -qF "$HASH" "$TOOL_FILE" 2>/dev/null; then
                TOOL_ENTRIES="${TOOL_ENTRIES}
<!-- hash:${HASH} worker:${worker} date:${TODAY} -->
${ENTRY}
"
            fi
        done
    fi
done

# Append new entries
if [ -n "$TASK_ENTRIES" ]; then
    echo "$TASK_ENTRIES" >> "$TASK_FILE"
    echo "Added new task insights to $TASK_FILE"
fi

if [ -n "$TOOL_ENTRIES" ]; then
    echo "$TOOL_ENTRIES" >> "$TOOL_FILE"
    echo "Added new tool entries to $TOOL_FILE"
fi

# Push to MinIO
mc cp --quiet "$TASK_FILE" "${MC_ALIAS}/${BUCKET}/shared/vault/agent-shared/task-insights.md" 2>/dev/null || true
mc cp --quiet "$TOOL_FILE" "${MC_ALIAS}/${BUCKET}/shared/vault/agent-shared/tool-guide.md" 2>/dev/null || true

echo "Memory aggregation complete."
```

- [ ] **Step 3: Make script executable**

```bash
chmod +x manager/agent/skills/memory-aggregation/scripts/aggregate-memories.sh
```

- [ ] **Step 4: Commit**

```bash
git add manager/agent/skills/memory-aggregation/
git commit -m "feat(manager): add memory-aggregation skill for cross-agent knowledge transfer"
```

---

## Phase 2: Add mcpvault MCP Server

### Task 6: Create mcpvault MCP Server Template

**Files:**
- Create: `manager/agent/skills/mcp-server-management/references/mcp-obsidian-vault.yaml`

- [ ] **Step 1: Create mcpvault YAML template**

Following the pattern from `mcp-github.yaml`, create the template:

```yaml
# manager/agent/skills/mcp-server-management/references/mcp-obsidian-vault.yaml
#
# MCP Server template for mcpvault — Obsidian vault read/write via
# filesystem.  mcpvault must be running as a sidecar or standalone
# process pointing at the shared vault directory.
#
# Usage:
#   bash scripts/setup-mcp-proxy.sh obsidian-vault http://localhost:3200/mcp sse
#
# mcpvault does not use credential substitution — it reads files
# directly from disk.  The proxy setup script handles Gateway routing
# and Worker authorization.
#
# Start mcpvault (example):
#   npx mcpvault --vault ~/hiclaw-fs/shared/vault --port 3200

server:
  name: obsidian-vault
  config: {}

tools:
  - name: search_notes
    description: "Full-text search across all markdown notes in the vault"

  - name: read_note
    description: "Read the full content of a specific note by path"

  - name: list_notes
    description: "List all notes, optionally filtered by directory"

  - name: list_by_tag
    description: "List notes that contain a specific tag"

  - name: get_backlinks
    description: "Find all notes that link to a given note via [[wikilinks]]"

  - name: create_note
    description: "Create a new markdown note at the specified path"

  - name: append_note
    description: "Append content to an existing note"
```

- [ ] **Step 2: Commit**

```bash
git add manager/agent/skills/mcp-server-management/references/mcp-obsidian-vault.yaml
git commit -m "feat(mcp): add mcpvault YAML template for Obsidian knowledge base"
```

---

### Task 7: Document mcpvault Deployment

**Files:**
- Modify: `shared/vault-scaffold/README.md`

- [ ] **Step 1: Add mcpvault deployment section to vault README**

Append to `shared/vault-scaffold/README.md`:

```markdown

## mcpvault MCP Server (Optional — Phase 2)

mcpvault provides Obsidian-aware tools (backlinks, tags, search) to agents
via the MCP protocol.  It reads markdown files directly — Obsidian does not
need to be running.

### Install mcpvault

```bash
npm install -g mcpvault
```

### Start mcpvault (Manager sidecar)

```bash
# Point at the MinIO-synced vault directory
mcpvault --vault ~/hiclaw-fs/shared/vault --port 3200 &
```

### Register with HiClaw

```bash
# From the Manager agent, run:
bash skills/mcp-server-management/scripts/setup-mcp-proxy.sh \
    obsidian-vault http://localhost:3200/mcp sse
```

This registers mcpvault through Higress Gateway.  All workers automatically
receive access via their `mcporter.json` config on next sync cycle.

### Verify

```bash
mcporter call obsidian-vault search_notes '{"query": "test"}'
```
```

- [ ] **Step 2: Commit**

```bash
git add shared/vault-scaffold/README.md
git commit -m "docs(memory): add mcpvault deployment instructions to vault README"
```

---

## Phase 3: Production Optimization

### Task 8: Local Embedding Model Configuration

**Files:**
- Modify: `shared/lib/hiclaw-env.sh`
- Modify: `shared/vault-scaffold/README.md`

- [ ] **Step 1: Add GPU embedding model documentation to hiclaw-env.sh**

In `shared/lib/hiclaw-env.sh`, after the `HICLAW_VAULT_PATH` export, add a comment block:

```bash
# Local embedding model override for GPU environments (e.g., 4070Ti).
# Set HICLAW_EMBEDDING_MODEL to a local model served via Ollama or vLLM:
#   export HICLAW_EMBEDDING_MODEL=bge-m3
# The model must be accessible via the AI Gateway at HICLAW_AI_GATEWAY_URL.
```

- [ ] **Step 2: Add production setup section to vault README**

Append to `shared/vault-scaffold/README.md`:

```markdown

## Production: Local Embedding on GPU (Phase 3)

For environments with a GPU (e.g., NVIDIA 4070Ti), run embeddings locally
instead of calling a remote API:

1. Serve an embedding model via Ollama:
   ```bash
   ollama pull bge-m3
   ollama serve
   ```

2. Configure HiClaw to use the local model:
   ```bash
   export HICLAW_EMBEDDING_MODEL=bge-m3
   export HICLAW_AI_GATEWAY_URL=http://localhost:11434
   ```

3. Restart the controller — all agents will use local embeddings on next
   config refresh.

Expected VRAM usage: ~1-2 GB for bge-m3.
```

- [ ] **Step 3: Commit**

```bash
git add shared/lib/hiclaw-env.sh shared/vault-scaffold/README.md
git commit -m "docs(memory): add local GPU embedding model setup instructions"
```

---

### Task 9: Integration Smoke Test

**Files:**
- Create: `copaw/tests/test_vault_sync.py`

- [ ] **Step 1: Write integration test for vault path flow**

This test verifies the full config flow: controller generates memorySearch with vaultPath → CoPaw bridge resolves it → agent config includes vault_path.

```python
"""Smoke test: vault path flows from controller config to agent config."""

import json
import tempfile
from pathlib import Path

from copaw_worker import bridge as bridge_module
from copaw_worker.bridge import bridge_controller_to_copaw


def test_vault_path_end_to_end(monkeypatch):
    """Controller → openclaw.json → CoPaw bridge → agent.json vault_path."""
    monkeypatch.setattr(bridge_module, "_is_in_container", lambda: True)

    openclaw_cfg = {
        "channels": {
            "matrix": {
                "homeserver": "http://matrix:6167",
                "accessToken": "tok",
                "userId": "@test:hiclaw.io",
            }
        },
        "models": {
            "providers": {
                "gw": {
                    "baseUrl": "http://aigw:8080/v1",
                    "apiKey": "key",
                    "models": [{"id": "qwen3.5-plus", "input": ["text"]}],
                }
            }
        },
        "agents": {
            "defaults": {
                "model": {"primary": "gw/qwen3.5-plus"},
                "memorySearch": {
                    "provider": "openai",
                    "model": "text-embedding-v4",
                    "vaultPath": "shared/vault",
                    "remote": {
                        "baseUrl": "http://aigw:8080/v1",
                        "apiKey": "key",
                    },
                },
            }
        },
    }

    with tempfile.TemporaryDirectory() as tmpdir:
        working_dir = Path(tmpdir) / "agent"
        bridge_controller_to_copaw(openclaw_cfg, working_dir)
        agent_json = json.loads(
            (working_dir / "workspaces" / "default" / "agent.json").read_text()
        )

    emb = agent_json["running"]["embedding_config"]
    assert emb["model_name"] == "text-embedding-v4"
    assert emb["vault_path"] == "shared/vault"
    assert emb["backend"] == "openai"
```

- [ ] **Step 2: Run the test**

Run: `cd copaw && python -m pytest tests/test_vault_sync.py -v`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add copaw/tests/test_vault_sync.py
git commit -m "test(copaw): add end-to-end smoke test for vault path config flow"
```

---

## Summary

| Task | Phase | Description | Files Changed |
|---|---|---|---|
| 1 | 1 | Vault scaffold | 5 new seed files |
| 2 | 1 | Controller vaultPath config | types.go, generator.go, config.go, hiclaw-env.sh |
| 3 | 1 | CoPaw bridge vault_path | bridge.py, test_bridge.py |
| 4 | 1 | Hermes bridge embedding | bridge.py, test_bridge_embedding.py |
| 5 | 1 | Manager aggregation skill | SKILL.md, aggregate-memories.sh |
| 6 | 2 | mcpvault YAML template | mcp-obsidian-vault.yaml |
| 7 | 2 | mcpvault deployment docs | README.md |
| 8 | 3 | Local GPU embedding docs | hiclaw-env.sh, README.md |
| 9 | 3 | Integration smoke test | test_vault_sync.py |
