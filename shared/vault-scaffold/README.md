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
