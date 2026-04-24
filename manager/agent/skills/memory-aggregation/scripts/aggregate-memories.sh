#!/usr/bin/env bash
# Aggregate worker task/tool memory into shared vault.
# Reads workers-registry.json, pulls per-worker memory files from MinIO,
# merges into shared/vault/agent-shared/.

set -euo pipefail

REGISTRY="${HOME}/workers-registry.json"
SHARED_DIR="${HOME}/shared/vault/agent-shared"
MC_ALIAS="${HICLAW_MC_ALIAS:-hiclaw}"
BUCKET="${HICLAW_FS_BUCKET:-hiclaw-storage}"
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

TASK_ENTRIES=""
TOOL_ENTRIES=""

for worker in $WORKERS; do
    WORKER_MEM="${MC_ALIAS}/${BUCKET}/agents/${worker}/memory"

    mc cp --quiet --recursive "${WORKER_MEM}/task-insights/" "$TMPDIR/${worker}/task/" 2>/dev/null || true
    mc cp --quiet --recursive "${WORKER_MEM}/tool-guide/" "$TMPDIR/${worker}/tool/" 2>/dev/null || true

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

if [ -n "$TASK_ENTRIES" ]; then
    echo "$TASK_ENTRIES" >> "$TASK_FILE"
    echo "Added new task insights to $TASK_FILE"
fi

if [ -n "$TOOL_ENTRIES" ]; then
    echo "$TOOL_ENTRIES" >> "$TOOL_FILE"
    echo "Added new tool entries to $TOOL_FILE"
fi

mc cp --quiet "$TASK_FILE" "${MC_ALIAS}/${BUCKET}/shared/vault/agent-shared/task-insights.md" 2>/dev/null || true
mc cp --quiet "$TOOL_FILE" "${MC_ALIAS}/${BUCKET}/shared/vault/agent-shared/tool-guide.md" 2>/dev/null || true

echo "Memory aggregation complete."
