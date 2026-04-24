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
