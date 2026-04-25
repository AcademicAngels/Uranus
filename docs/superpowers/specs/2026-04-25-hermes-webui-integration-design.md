# Hermes Web UI Integration Design

**Date:** 2026-04-25
**Status:** Draft
**Scope:** Integrate hermes-web-ui into HiClaw Hermes Worker containers for OPC developers

## Problem Statement

HiClaw lacks a unified Web UI for agent configuration, token monitoring, and task scheduling. OPC developers must split effort across 3 consoles (MinIO for files, Higress for gateway, OpenClaw Control UI for runtime) and manually edit JSON/YAML. hermes-web-ui provides all these capabilities and is 80%+ compatible with HiClaw's Hermes Worker.

## Constraints

- Target: individual developers / personal use (OPC)
- Must not conflict with upstream HiClaw pull (minimal fork divergence)
- Must not break existing deployment flow
- hermes-web-ui runs as sidecar process inside Hermes Worker container (not a separate container)
- Auth.json compatibility: single provider pointing at Higress Gateway

## Solution

### Deployment Architecture

```
Hermes Worker Container
├── hermes-agent gateway (:8642)      ← main process (existing)
├── sync.py / mc mirror               ← file sync (existing)
├── mcpvault (:3200)                   ← MCP server (pre-installed)
└── hermes-web-ui (:6060)             ← NEW sidecar process
    ├── UPSTREAM=http://127.0.0.1:8642
    ├── HERMES_HOME=~/.hermes
    └── AUTH_DISABLED=true (single-user, behind gateway auth)
```

### Changes

#### 1. Dockerfile: Pre-install hermes-web-ui

Add `hermes-web-ui` to the npm install line in `hermes/Dockerfile` (alongside mcpvault):

```dockerfile
npm install -g mcporter skills @nacos-group/cli mcpvault hermes-web-ui
```

#### 2. Entrypoint: Start hermes-web-ui sidecar

In `hermes/scripts/hermes-worker-entrypoint.sh`, after the gateway startup section, add:

```bash
# Start hermes-web-ui if installed
if command -v hermes-web-ui >/dev/null 2>&1; then
    WEBUI_PORT="${HICLAW_WEBUI_PORT:-6060}"
    AUTH_DISABLED=true \
    UPSTREAM="http://127.0.0.1:8642" \
    PORT="${WEBUI_PORT}" \
    hermes-web-ui start --port "${WEBUI_PORT}" &
    log "hermes-web-ui started on port ${WEBUI_PORT}"
fi
```

Auth is disabled because the container is already behind Higress Gateway auth (Gateway Key). Adding a second auth layer would frustrate OPC users.

#### 3. Entrypoint: Initialize auth.json for Higress Gateway

In the entrypoint, before starting hermes-web-ui, generate `~/.hermes/auth.json` if it doesn't exist:

```bash
AUTH_JSON="${HERMES_HOME}/auth.json"
if [ ! -f "${AUTH_JSON}" ]; then
    cat > "${AUTH_JSON}" <<AUTHJSON
{
  "providers": {
    "hiclaw-gateway": {
      "url": "${HICLAW_AI_GATEWAY_URL:-http://aigw-local.hiclaw.io:8080}/v1",
      "key": "${GATEWAY_KEY}"
    }
  },
  "default": "hiclaw-gateway"
}
AUTHJSON
    log "auth.json initialized for Higress Gateway"
fi
```

This lets hermes-web-ui's model management page discover models through the Higress AI Gateway.

#### 4. Port Exposure

For Docker deployment: add `-p 6060:6060` to worker container run command.

For K8s deployment: Worker CRD `expose` field or Higress route.

The install script and generate-worker-config.sh already support port configuration via the Worker CRD `expose` array. No install script changes needed.

### Config Ownership: What hermes-web-ui Can and Cannot Change

| Config Area | hermes-web-ui Writes | bridge.py Overwrites? | Safe? |
|---|---|---|---|
| `config.yaml` model block | Yes (via settings) | Yes (bridge-owned) | ⚠️ Changes lost on restart — use HiClaw model-switch skill instead |
| `config.yaml` terminal/scheduler/agent | Yes | No (not bridge-owned) | ✅ Safe |
| `config.yaml` memory | Yes | No (setdefault only) | ✅ Safe |
| `.env` MATRIX_* keys | Yes | Yes (bridge-owned) | ⚠️ Changes lost — use HiClaw channel-management |
| `auth.json` | Yes | No (bridge doesn't touch) | ✅ Safe |
| `skills/` directory | Read only | No | ✅ Safe |
| Cron jobs | Yes (via gateway API) | No | ✅ Safe |

### What This Design Does NOT Include

- No new Helm chart values (hermes-web-ui is optional, containerized)
- No changes to bridge.py (ownership rules already correct)
- No changes to generator.go (OpenClaw config unaffected)
- No changes to sync.py (file sync unaffected)
- No sandbox/terminal configuration changes (confirmed: each runtime uses native sandbox, bridge doesn't override)
- No separate container for hermes-web-ui (sidecar in Worker container)

## Files to Modify

| File | Change |
|---|---|
| `hermes/Dockerfile` | Add `hermes-web-ui` to npm install |
| `hermes/scripts/hermes-worker-entrypoint.sh` | Add auth.json init + hermes-web-ui sidecar start |

## Verification

1. Build Hermes Worker image: `make build-hermes-worker`
2. Start a Hermes Worker with Web UI port exposed
3. Access `http://localhost:6060` — should show hermes-web-ui login/dashboard
4. Verify model discovery works (auth.json → Higress Gateway → model list)
5. Verify cron job creation works
6. Verify settings changes persist across bridge.py restarts (non-bridge-owned fields)
