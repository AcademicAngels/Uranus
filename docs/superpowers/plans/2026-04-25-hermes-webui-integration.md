# Hermes Web UI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pre-install hermes-web-ui in Hermes Worker containers and auto-start it as a sidecar, giving OPC developers a full Web UI for agent configuration, token monitoring, and cron job management.

**Architecture:** Two-file change. Dockerfile adds the npm package. Entrypoint initializes auth.json (pointing at Higress Gateway) and launches hermes-web-ui as a background daemon before `exec`-ing the main hermes-worker process.

**Tech Stack:** Bash (entrypoint), Docker (Dockerfile), npm (hermes-web-ui package)

**Spec:** `docs/superpowers/specs/2026-04-25-hermes-webui-integration-design.md`

---

## File Structure

### Modified Files
| File | Change |
|---|---|
| `hermes/Dockerfile:79` | Add `hermes-web-ui` to npm install line |
| `hermes/scripts/hermes-worker-entrypoint.sh:144-156` | Add auth.json init + hermes-web-ui sidecar start before final `exec` |

---

### Task 1: Add hermes-web-ui to Dockerfile

**Files:**
- Modify: `hermes/Dockerfile:79`

- [ ] **Step 1: Add hermes-web-ui to npm install**

In `hermes/Dockerfile`, change line 79 from:

```dockerfile
    npm install -g mcporter skills @nacos-group/cli mcpvault && \
```

To:

```dockerfile
    npm install -g mcporter skills @nacos-group/cli mcpvault hermes-web-ui && \
```

- [ ] **Step 2: Commit**

```bash
git add hermes/Dockerfile
git commit --author="吉尔伽美什 <>" -m "feat(docker): pre-install hermes-web-ui in hermes worker image"
```

---

### Task 2: Add auth.json Initialization and Web UI Sidecar to Entrypoint

**Files:**
- Modify: `hermes/scripts/hermes-worker-entrypoint.sh:144-156`

The current end of the entrypoint (lines 144-156) is:

```bash
CMD_ARGS=(
    --name "${WORKER_NAME}"
    --fs "${FS_ENDPOINT}"
    --fs-key "${FS_ACCESS_KEY}"
    --fs-secret "${FS_SECRET_KEY}"
    --fs-bucket "${FS_BUCKET}"
    --install-dir "${INSTALL_DIR}"
)

_start_readiness_reporter

exec "${VENV}/bin/hermes-worker" "${CMD_ARGS[@]}"
```

- [ ] **Step 1: Add auth.json initialization**

Insert the following block **before** `CMD_ARGS=(` (before line 145), after line 143 (`fi` closing the OTel block):

```bash

# ── Hermes Web UI: auth.json for Higress Gateway ──────────────────────────
# hermes-web-ui uses auth.json to discover LLM providers.  Seed a single
# "hiclaw-gateway" provider that routes through Higress so the Web UI's model
# selector and usage analytics work out of the box.  The file is never
# overwritten if the user has edited it.
AUTH_JSON="${HERMES_HOME}/auth.json"
if [ ! -f "${AUTH_JSON}" ]; then
    _gw_url="${HICLAW_AI_GATEWAY_URL:-http://aigw-local.hiclaw.io:8080}/v1"
    _gw_key="${HICLAW_WORKER_API_KEY:-${HICLAW_AUTH_TOKEN:-}}"
    cat > "${AUTH_JSON}" <<AUTHJSON
{
  "providers": {
    "hiclaw-gateway": {
      "url": "${_gw_url}",
      "key": "${_gw_key}"
    }
  },
  "default": "hiclaw-gateway"
}
AUTHJSON
    log "auth.json initialized for Higress Gateway (${_gw_url})"
fi
```

- [ ] **Step 2: Add hermes-web-ui sidecar startup**

Insert the following block **after** the auth.json block and **before** `CMD_ARGS=(`:

```bash

# ── Hermes Web UI: start as background sidecar ────────────────────────────
# Auth is disabled because the container is already behind Higress Gateway
# key-auth.  The UPSTREAM points at the local hermes-agent gateway.
if command -v hermes-web-ui >/dev/null 2>&1; then
    WEBUI_PORT="${HICLAW_WEBUI_PORT:-6060}"
    AUTH_DISABLED=true \
    UPSTREAM="http://127.0.0.1:8642" \
    HERMES_BIN="${VENV}/bin/hermes" \
    PORT="${WEBUI_PORT}" \
    hermes-web-ui start --port "${WEBUI_PORT}" &
    log "hermes-web-ui started on port ${WEBUI_PORT} (auth disabled, upstream=localhost:8642)"
fi
```

- [ ] **Step 3: Verify the entrypoint syntax**

Run: `bash -n hermes/scripts/hermes-worker-entrypoint.sh && echo "Syntax OK"`

Expected: `Syntax OK`

- [ ] **Step 4: Verify the full insertion order is correct**

Run: `grep -n 'auth.json\|hermes-web-ui\|CMD_ARGS\|exec.*hermes-worker' hermes/scripts/hermes-worker-entrypoint.sh`

Expected output should show auth.json init → hermes-web-ui start → CMD_ARGS → exec, in that order.

- [ ] **Step 5: Commit**

```bash
git add hermes/scripts/hermes-worker-entrypoint.sh
git commit --author="吉尔伽美什 <>" -m "feat(hermes): auto-start hermes-web-ui sidecar with Higress auth.json"
```

---

## Summary

| Task | Description | Files Changed |
|---|---|---|
| 1 | Dockerfile npm install | hermes/Dockerfile |
| 2 | Entrypoint auth.json + sidecar | hermes/scripts/hermes-worker-entrypoint.sh |
