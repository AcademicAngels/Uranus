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
