---
name: worker-management
description: Manage the full lifecycle of Worker Agents (create, configure, monitor, credential rotation, reset). Use when the human admin requests creating a new worker, rotating credentials, or resetting a worker.
---

# Worker Management

## Overview

This skill allows you to manage the full lifecycle of Worker Agents: creation, configuration, monitoring, credential rotation, and reset. Workers are lightweight containers that connect to the Manager via Matrix and use the centralized file system.

## Create a Worker

Follow these steps in order. Use the `higress-gateway-management` and `matrix-server-management` skills for the API calls.

### Step 1: Register Matrix Account

```bash
curl -X POST http://127.0.0.1:6167/_matrix/client/v3/register \
  -H 'Content-Type: application/json' \
  -d '{
    "username": "<WORKER_NAME>",
    "password": "<GENERATED_PASSWORD>",
    "auth": {
      "type": "m.login.registration_token",
      "token": "'"${HICLAW_REGISTRATION_TOKEN}"'"
    }
  }'
```

### Step 2: Create Matrix Room (3-party)

Create a Room with the human admin, Manager, and new Worker. See `matrix-server-management` SKILL.md for the exact API call.

### Step 3: Create Higress Consumer (key-auth)

```bash
WORKER_KEY=$(openssl rand -hex 32)
curl -X POST http://127.0.0.1:8001/v1/consumers \
  -b "${HIGRESS_COOKIE_FILE}" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "worker-<WORKER_NAME>",
    "credentials": [{
      "type": "key-auth",
      "source": "BEARER",
      "values": ["'"${WORKER_KEY}"'"]
    }]
  }'
```

### Step 4: Authorize Route Access

Add the Worker consumer to all relevant routes (AI Gateway, HTTP filesystem, MCP Server):

```bash
# For each route: GET, add consumer to allowedConsumers, PUT back
# See higress-gateway-management SKILL.md for the GET-modify-PUT pattern
```

### Step 5: Authorize MCP Server Access (if applicable)

See the **`mcp-server-management`** skill for the full API reference. The key operation is:

```bash
# Add Worker to existing MCP consumer list (this is a REPLACE, include ALL consumers)
curl -X PUT http://127.0.0.1:8001/v1/mcpServer/consumers \
  -b "${HIGRESS_COOKIE_FILE}" \
  -H 'Content-Type: application/json' \
  -d '{
    "mcpServerName": "mcp-github",
    "consumers": ["manager", "worker-<WORKER_NAME>"]
  }'
```

Also create the Worker's MCP server config file (see `mcp-server-management` skill, "Worker MCP Server Config File" section).

### Step 6: Generate Worker Configuration Files

Write the following files to MinIO (via the local mirror at ~/hiclaw-fs/):

1. `~/hiclaw-fs/agents/<WORKER_NAME>/SOUL.md` - Worker identity and task instructions
2. `~/hiclaw-fs/agents/<WORKER_NAME>/openclaw.json` - OpenClaw config with:
   - Matrix credentials (the Worker account password)
   - groupAllowFrom: Manager + Admin
   - Model config pointing to AI Gateway with Worker's consumer key
   - No heartbeat (Manager inquires via Room)
3. `~/hiclaw-fs/agents/<WORKER_NAME>/mcporter-servers.json` - MCP server endpoints (if MCP access granted)

### Step 7: Update Manager groupAllowFrom

Add the new Worker to your own openclaw.json groupAllowFrom so you can receive messages from them in Rooms.

Use the `config.patch` API or update the config file directly (file-watch triggers hot reload in ~300ms):

```bash
# Update config file directly:
jq --arg worker "@<WORKER_NAME>:${HICLAW_MATRIX_DOMAIN}" \
  '.channels.matrix.groupAllowFrom += [$worker]' \
  ~/hiclaw-fs/agents/manager/openclaw.json > /tmp/config-updated.json
mv /tmp/config-updated.json ~/hiclaw-fs/agents/manager/openclaw.json
```

### Step 8: Start Worker (Two Modes)

Choose the appropriate mode based on the human admin's request:

#### Mode A: Direct Creation (Local Deployment)

Use this when the admin asks to "directly create", "launch locally", or "start the worker here".
This requires the container runtime socket to be mounted in the Manager container.

```bash
# Check if container runtime is available
source /opt/hiclaw/scripts/container-api.sh
if container_api_available; then
    # Create and start the Worker container on the host
    CONTAINER_ID=$(container_create_worker "<WORKER_NAME>")
    if [ -n "${CONTAINER_ID}" ]; then
        echo "Worker <WORKER_NAME> started as container: ${CONTAINER_ID:0:12}"
    fi
fi
```

The `container_create_worker` function automatically:
- Sets the Worker image (`HICLAW_WORKER_IMAGE` env, defaults to `hiclaw/worker-agent:latest`)
- Passes MinIO credentials and endpoint (derived from Manager's own IP)
- Creates the container on the host via the mounted socket
- Starts the container

After creation, verify the Worker is running:
```bash
container_status_worker "<WORKER_NAME>"   # Should return "running"
container_logs_worker "<WORKER_NAME>" 20  # Check startup logs
```

#### Mode B: Output Install Command (Remote Deployment)

Use this when the admin wants to run the Worker on a different machine, or when the container runtime socket is not available.

Tell the human admin the command to install the Worker:

```
Run this command to start Worker <WORKER_NAME>:

curl -fsSL https://raw.githubusercontent.com/higress-group/hiclaw/main/install/hiclaw-install.sh | bash -s worker \
  --name <WORKER_NAME> \
  --matrix-server http://<MATRIX_DOMAIN>:8080 \
  --gateway http://<AI_GATEWAY_DOMAIN>:8080 \
  --fs http://<FS_DOMAIN>:8080 \
  --fs-key <FS_ACCESS_KEY> \
  --fs-secret <FS_SECRET_KEY>
```

**IMPORTANT**: Do NOT include the Worker's Matrix password, API key, or gateway key in the install command or Room messages. These are passed via configuration files in the centralized file system.

#### How to Decide

- If the admin says "直接创建" / "直接启动" / "locally" / "create it directly" → **Mode A**
- If the admin says "给我命令" / "remote" / doesn't specify → **Mode B**
- If Mode A fails (socket not available), fall back to **Mode B** and explain why

## Monitor Workers

### Heartbeat Check (automated every 15 minutes)

The heartbeat prompt triggers automatically. When it fires:

1. Check each Worker's Room for recent messages
2. For Workers with assigned tasks and no completion notification, ask for status in their Room
3. Check credential expiration
4. Assess capacity vs pending tasks

### Manual Status Check

```bash
# Check if a Worker container is running (Worker should be sending heartbeat-like messages)
# Check the Worker's Room for recent activity:
curl -s "http://127.0.0.1:6167/_matrix/client/v3/rooms/<ROOM_ID>/messages?dir=b&limit=5" \
  -H "Authorization: Bearer <MANAGER_TOKEN>" | jq '.chunk[].content.body'
```

## Credential Rotation

Uses dual-key sliding window to prevent downtime:

1. Generate new key
2. Add new key alongside old key (Consumer has 2 values)
3. Update Worker's config file (will be synced via mc mirror)
4. Wait for Worker to pick up new config (~300ms file-watch)
5. Verify Worker can auth with new key
6. Remove old key from Consumer

See `higress-gateway-management` SKILL.md for the exact API calls.

## Reset a Worker

1. Revoke the Worker's Higress Consumer (or update credentials)
2. Remove Worker from all route auth configs
3. Remove Worker from MCP Server consumer lists
4. Delete Worker's config directory: `rm -rf ~/hiclaw-fs/agents/<WORKER_NAME>/`
5. Re-create from scratch (Steps 1-8 above)
6. The human runs the install command with `--reset` flag

## Important Notes

- Workers are **stateless containers** -- all state is in MinIO. Resetting a Worker just means recreating its config files
- Worker Matrix accounts persist in Tuwunel (cannot be deleted via API). Reuse same username on reset
- OpenClaw config hot-reload: file-watch (~300ms) or `config.patch` API
- Worker's `exec` tool timeout: 10 minutes
- MinIO file sync: local->remote is real-time, remote->local pulls every 5 minutes
