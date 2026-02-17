---
name: higress-gateway-management
description: Manage the Higress AI Gateway via its Console API (consumers, routes, AI providers, MCP servers). Use when creating consumers, configuring routes, or managing AI gateway settings.
---

# Higress AI Gateway Management

## Overview

This skill allows you to manage the Higress AI Gateway via its Console API. The Console API runs at `http://127.0.0.1:8001` and uses **Session Cookie** authentication (NOT Basic Auth).

## Authentication

A session cookie file is stored at the path in `${HIGRESS_COOKIE_FILE}` environment variable. Use it with `curl -b "${HIGRESS_COOKIE_FILE}"`.

If the cookie expires, re-login:

```bash
curl -X POST http://127.0.0.1:8001/session/login \
  -H 'Content-Type: application/json' \
  -c "${HIGRESS_COOKIE_FILE}" \
  -d '{"name": "'"${HICLAW_ADMIN_USER}"'", "password": "'"${HICLAW_ADMIN_PASSWORD}"'"}'
```

## Consumer Management

### List Consumers

```bash
curl -s http://127.0.0.1:8001/v1/consumers -b "${HIGRESS_COOKIE_FILE}" | jq
```

### Create Consumer

```bash
curl -X POST http://127.0.0.1:8001/v1/consumers \
  -b "${HIGRESS_COOKIE_FILE}" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "worker-alice",
    "credentials": [{
      "type": "key-auth",
      "source": "BEARER",
      "values": ["<GENERATED_KEY>"]
    }]
  }'
```

### Update Consumer (e.g., credential rotation with dual-key sliding window)

```bash
# Step 1: GET current consumer
CONSUMER=$(curl -s http://127.0.0.1:8001/v1/consumers/worker-alice -b "${HIGRESS_COOKIE_FILE}")

# Step 2: Add new key alongside old one (dual-key window)
NEW_KEY=$(openssl rand -hex 32)
OLD_KEY=$(echo $CONSUMER | jq -r '.credentials[0].values[0]')
UPDATED=$(echo $CONSUMER | jq --arg new "$NEW_KEY" --arg old "$OLD_KEY" \
  '.credentials[0].values = [$new, $old]')

# Step 3: PUT full object back
curl -X PUT http://127.0.0.1:8001/v1/consumers/worker-alice \
  -b "${HIGRESS_COOKIE_FILE}" \
  -H 'Content-Type: application/json' \
  -d "$UPDATED"

# Step 4: After Worker confirms new key works, remove old key
FINAL=$(echo $CONSUMER | jq --arg new "$NEW_KEY" '.credentials[0].values = [$new]')
curl -X PUT http://127.0.0.1:8001/v1/consumers/worker-alice \
  -b "${HIGRESS_COOKIE_FILE}" \
  -H 'Content-Type: application/json' \
  -d "$FINAL"
```

### Delete Consumer

```bash
curl -X DELETE http://127.0.0.1:8001/v1/consumers/worker-alice -b "${HIGRESS_COOKIE_FILE}"
```

## Route Management

**IMPORTANT**: Route updates use GET-modify-PUT pattern. You must send the complete object.

### List Routes

```bash
curl -s http://127.0.0.1:8001/v1/routes -b "${HIGRESS_COOKIE_FILE}" | jq
```

### Get Route by Name

```bash
curl -s http://127.0.0.1:8001/v1/routes/http-filesystem -b "${HIGRESS_COOKIE_FILE}" | jq
```

### Update Route Auth (add/remove Consumer access)

```bash
# Step 1: GET current route
ROUTE=$(curl -s http://127.0.0.1:8001/v1/routes/http-filesystem -b "${HIGRESS_COOKIE_FILE}")

# Step 2: Add worker-alice to allowedConsumers
UPDATED=$(echo $ROUTE | jq '.authConfig.allowedConsumers += ["worker-alice"]')

# Step 3: PUT full object (note: Route has "version" field, include it)
curl -X PUT http://127.0.0.1:8001/v1/routes/http-filesystem \
  -b "${HIGRESS_COOKIE_FILE}" \
  -H 'Content-Type: application/json' \
  -d "$UPDATED"
```

## LLM Provider Configuration

### List AI Providers

```bash
curl -s http://127.0.0.1:8001/v1/ai/providers -b "${HIGRESS_COOKIE_FILE}" | jq
```

### Update Provider (add API keys for rotation)

```bash
curl -X PUT http://127.0.0.1:8001/v1/ai/providers/<provider-name> \
  -b "${HIGRESS_COOKIE_FILE}" \
  -H 'Content-Type: application/json' \
  -d '{...}'
```

## MCP Server Management

For creating, updating, listing, and deleting MCP Servers, as well as managing consumer access to MCP tools, see the **`mcp-server-management`** skill.

## Important Notes

- **Auth Plugin Activation**: First configuration takes ~40s, subsequent changes ~10s
- **Route version**: Routes have a `version` field. Always GET before PUT to get the latest version
- **Consumer version**: Consumers do NOT have a `version` field
- **MCP Server**: See `mcp-server-management` skill for full details on creating and managing MCP servers
