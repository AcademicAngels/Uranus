# Shared Memory System Design for Uranus (HiClaw)

**Date:** 2026-04-24
**Status:** Draft
**Scope:** Personal-use shared memory for Hermes (Manager) / OpenClaw (Worker) / QwenClaw (Light Worker)

## Problem Statement

The current MinIO file-sync memory system provides basic knowledge reuse, context continuation, and external knowledge access, but suffers from four key shortcomings:

1. **No semantic search** — text matching only; cannot retrieve semantically related memories (e.g., "similar error handling" won't find past experiences)
2. **Low retrieval efficiency** — agents must read entire files to find relevant memories, wasting tokens and time
3. **No structured knowledge** — raw conversation/file dumps without extracting "who solved what, when, and how"
4. **Poor cross-agent transfer** — experiences learned by one agent don't automatically flow to others

## Constraints

- **Target users:** Individual developers and personal use
- **Development environment:** <8 GB RAM — no heavy services
- **Production environment:** Windows, 20 GB RAM, NVIDIA 4070Ti GPU
- **Principle:** No over-engineering; avoid independent services where embedded alternatives exist
- **Existing infrastructure:** MinIO (object storage), Higress (AI Gateway), Matrix (messaging), ReMe (lazy-loaded via CoPaw/AgentScope)

## Solution: Hybrid Architecture (ReMe + Obsidian MCP)

Two-layer design where each layer handles what it does best:

- **ReMe layer:** Agent memory lifecycle management — compression, persistence, retrieval, decay
- **MCP layer:** Human knowledge queries — backlinks, tags, full-text search against Obsidian vault

### Architecture Overview

```
┌────────────────────────────────────────────────────────────────┐
│                        Admin (you)                              │
│                                                                │
│  Obsidian Vault (local)                                        │
│  ├── knowledge/        ← your notes / references               │
│  ├── agent-shared/     ← agent-written structured insights     │
│  │   ├── task-insights.md                                      │
│  │   ├── tool-guide.md                                         │
│  │   └── daily/YYYY-MM-DD.md                                   │
│  └── agent-private/    ← per-agent memories (viewable by you)  │
│      ├── hermes/MEMORY.md                                      │
│      ├── openclaw/MEMORY.md                                    │
│      └── qwenclaw/MEMORY.md                                    │
└────────────────────────────┬───────────────────────────────────┘
                             │ mc mirror (bidirectional)
┌────────────────────────────▼───────────────────────────────────┐
│  MinIO (existing)                                              │
│  ├── shared/vault/          ← Obsidian vault mirror            │
│  ├── agents/hermes/memory/  ← ReMe memory files                │
│  ├── agents/alice/memory/                                      │
│  └── agents/qwen/memory/                                       │
└────────────────────────────┬───────────────────────────────────┘
                             │ sync.py pull (existing, 30s cycle)
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
┌──────────────────┐ ┌─────────────┐ ┌─────────────┐
│     Hermes       │ │  OpenClaw   │ │  QwenClaw   │
│    (Manager)     │ │  (Worker)   │ │  (Worker)   │
│                  │ │             │ │             │
│ ReMe memory mgmt │ │ ReMe memory │ │ ReMe memory │
│ mcpvault queries │ │ mcpvault    │ │ mcpvault    │
└──────────────────┘ └─────────────┘ └─────────────┘
```

## Layer 1: ReMe Memory Management

### Memory Classification and Sharing Policy

| Memory Type | Scope | Storage | Shared? |
|---|---|---|---|
| Personal Memory (user preferences, admin habits) | Per-agent | `agents/{name}/memory/` | Private |
| Task Memory (success/failure/comparison insights) | Per-agent → aggregated | `agents/{name}/memory/` → `shared/vault/agent-shared/` | Yes |
| Tool Memory (tool selection, parameter tuning) | Per-agent → aggregated | Same as above | Yes |
| Working Memory (context compression) | In-process | Not persisted | N/A |

### Vector Retrieval: LocalVectorStore (Embedded)

No standalone vector service. Use ReMe's built-in `LocalVectorStore`:

- Each agent process runs a LocalVectorStore instance in-process
- Indexes two sources: own `memory/` + `shared/vault/`
- Hybrid retrieval: vector similarity 0.7 + BM25 keyword 0.3 (ReMe default)
- ~50 MB additional memory per agent

### Embedding Strategy

| Environment | Method | Model | Resource |
|---|---|---|---|
| Development (<8 GB) | Remote via Higress AI Gateway | `text-embedding-v4` | ~0 local |
| Production (4070Ti) | Local GPU | `bge-m3` or `gte-Qwen2` | ~1-2 GB VRAM |

Switched via existing `HICLAW_EMBEDDING_MODEL` environment variable — no code changes needed.

### Cross-Agent Knowledge Transfer

```
Agent completes task
    │
    ▼
ReMe Task Memory auto-extracts three knowledge types:
  - success_extraction: "solved Y with method X"
  - failure_extraction: "Z didn't work because..."
  - comparative_extraction: "A suits better than B for..."
    │
    ▼
Written to local memory/task-insights/
    │
    ▼
sync.py push → MinIO agents/{name}/memory/
    │
    ▼
Hermes (Manager) periodic aggregation (daily at idle time, configurable):
  Pull all worker task-insights/
  Deduplicate + merge → shared/vault/agent-shared/task-insights.md
    │
    ▼
sync.py pull → all agents receive shared insights
```

### Hermes Manager Memory: Selective Sharing

| Hermes Memory Type | Shared? | Reason |
|---|---|---|
| Personal Memory (admin preferences) | Private | Contains personal communication style |
| Task Memory (task decision experience) | Shared | Workers benefit from global task context |
| Tool Memory (tool optimization) | Shared | Manager's tool experience helps workers |
| Team management state (worker evaluation, scheduling) | Private | Should not be exposed to workers |

## Layer 2: Obsidian MCP Knowledge Query

### MCP Server: mcpvault

Selected [mcpvault](https://github.com/bitbonsai/mcpvault) for:
- No Obsidian desktop dependency — reads/writes markdown files directly
- Single binary, suitable for server-side deployment
- Backlink resolution and tag queries built-in
- Write capability for agent output

### Deployment: Manager Container Sidecar

```
Manager Container (existing)
├── Hermes Agent (main process)
├── mc mirror (existing, file sync)
├── mcpvault (new sidecar)           ← only new process
│   └── watches shared/vault/ directory
│   └── exposes MCP over HTTP
│
└── Higress Gateway (existing)
    └── /mcp-servers/obsidian/mcp   ← new route
```

Registered via existing `setup-mcp-server.sh` — all workers automatically receive access through mcporter config.

### Available MCP Tools

| Tool | Purpose | Example |
|---|---|---|
| `search_notes(query)` | Full-text / semantic note search | "previous CI deployment decisions" |
| `read_note(path)` | Read full note content | "knowledge/arch-decisions.md" |
| `list_by_tag(tag)` | List notes by tag | "#project/uranus" |
| `get_backlinks(path)` | Find notes referencing this note | Discover related context |
| `create_note(path, content)` | Agent writes new note | Task memory aggregation results |
| `append_note(path, content)` | Agent appends content | Daily logs |

### Retrieval Decision Flow

```
Agent needs memory:

1. "Have I done something similar before?"
   → ReMe memory_search (hybrid retrieval on own memory/)
   → Found: use directly
   → Not found: ↓

2. "Has another team member done something similar?"
   → ReMe memory_search (retrieve from shared/vault/agent-shared/)
   → Found: use directly
   → Not found: ↓

3. "Is there relevant material in admin's knowledge base?"
   → MCP search_notes (search Obsidian vault knowledge/)
   → Found: read and use
   → Not found: execute from scratch
```

## Obsidian Vault Directory Structure

```
obsidian-vault/
├── .obsidian/                     # Obsidian config (NOT synced to MinIO)
│
├── knowledge/                     # Human knowledge (you write and maintain)
│   ├── projects/
│   ├── references/
│   ├── decisions/
│   └── howtos/
│
├── agent-shared/                  # Agent shared memory (agents write, you can edit)
│   ├── task-insights.md
│   ├── tool-guide.md
│   └── daily/
│       └── YYYY-MM-DD.md
│
└── agent-private/                 # Per-agent private memory (you can view)
    ├── hermes/
    │   ├── MEMORY.md
    │   └── memory/YYYY-MM-DD.md
    ├── openclaw/
    │   └── ...
    └── qwenclaw/
        └── ...
```

### MinIO Path Mapping

| Obsidian Path | MinIO Path |
|---|---|
| `knowledge/` | `shared/vault/knowledge/` |
| `agent-shared/` | `shared/vault/agent-shared/` |
| `agent-private/hermes/` | `agents/hermes/memory/` |
| `agent-private/openclaw/` | `agents/alice/memory/` |
| `agent-private/qwenclaw/` | `agents/qwen/memory/` |
| `.obsidian/` | Not synced |

## Error Handling and Graceful Degradation

| Scenario | Behavior |
|---|---|
| MCP server unavailable | Agent falls back to ReMe file-based retrieval only; core functionality unaffected |
| MinIO sync delay | 30s pull cycle + Matrix notification triggers immediate pull (existing mechanism) |
| Vault file conflict | Last-write-wins (MinIO default); Obsidian has version history for rollback |
| Embedding service unavailable | ReMe falls back to BM25 keyword search only |

## Implementation Phases

### Phase 1: Enable ReMe + Shared Vault via MinIO
- Enable ReMe's LocalVectorStore + memory_search for all three runtimes
- Set up Obsidian vault ↔ MinIO bidirectional sync
- Configure `shared/vault/` path in sync.py
- Hermes aggregation task for cross-agent knowledge transfer

### Phase 2: Add mcpvault MCP Server
- Deploy mcpvault as Manager container sidecar
- Register via `setup-mcp-server.sh` → Higress route
- All workers receive mcpvault access automatically via mcporter config
- Implement retrieval decision flow (ReMe first → MCP fallback)

### Phase 3: Production Optimization
- Switch to local embedding model on 4070Ti (bge-m3 / gte-Qwen2)
- Tune vector index for vault size
- Add Hermes periodic aggregation scheduling (daily/weekly)

## What This Design Does NOT Include

- No standalone vector database (Qdrant, Milvus, etc.)
- No graph database (Neo4j, etc.)
- No new persistent services beyond mcpvault sidecar
- No knowledge graph or temporal reasoning
- No multi-user access control (personal use only)

These can be added later if usage patterns demand them, but are explicitly excluded to avoid over-engineering for personal use.
