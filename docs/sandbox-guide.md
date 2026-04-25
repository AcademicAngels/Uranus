# Sandbox & Code Execution Configuration Guide

*For OPC (Operator / Platform / Configuration) developers*

---

## Overview

Each HiClaw worker runtime ships with native code execution capabilities. HiClaw does **not** override or unify sandbox settings across runtimes:

- `bridge.py` uses `setdefault` when injecting configuration — it will never overwrite a key that already exists.
- `generator.go` does not touch exec-related configuration at all.

This means **OPC developers have full control** over sandbox behavior through each runtime's own configuration files and environment variables. This guide explains what each runtime offers and how to configure it.

---

## Choosing the Right Runtime

| Task Type | Recommended Runtime | Sandbox | Why |
|---|---|---|---|
| Coding / DevOps | Hermes | Terminal sandbox (6 backends) | Full terminal with PTY, background jobs, crash recovery |
| Content creation / scripting | OpenClaw | exec tool + optional Docker sandbox | Lightweight, sufficient for scripts |
| API calls / data processing | CoPaw / QwenPaw | execute_shell_command + Tool Guard | Rule-based security, lightweight |
| API-only tasks (no code exec) | Any | No sandbox needed | MCP tools handle external service calls |

---

## Hermes Sandbox

Hermes provides a full PTY-based terminal experience. The execution backend is selected via a single config key and supports six options.

### Available Backends

| Backend | Use Case | Setup |
|---|---|---|
| `local` (default in HiClaw) | Container is the security boundary | No setup needed |
| `docker` | Isolated container execution | Requires Docker socket access |
| `ssh` | Remote machine execution | SSH credentials required |
| `daytona` | Cloud dev environment | Daytona account required |
| `singularity` | HPC environments | Singularity installed |
| `modal` | Serverless GPU execution | Modal account required |

### Configuration

**Via `~/.hermes/config.yaml`:**

```yaml
terminal:
  backend: local    # change to docker, ssh, etc.
  cwd: /workspace
```

**Via hermes-web-ui:** navigate to the Settings page and select the terminal section. The web UI writes changes back to `config.yaml`.

### HiClaw-Specific Note: YOLO Mode

HiClaw sets `HERMES_YOLO_MODE=1` in the worker container entrypoint. This bypasses the interactive dangerous-command approval gate that Hermes would otherwise display before executing commands like `rm -rf`. With YOLO mode enabled, commands execute immediately without prompting.

**Security boundary:** the worker container itself. YOLO mode is appropriate when the container is already isolated (e.g., running inside Kubernetes with no sensitive mounts). If you need per-command approval, unset `HERMES_YOLO_MODE` or switch to the `docker` backend, which adds a second isolation layer.

---

## OpenClaw Sandbox

OpenClaw exposes an `exec` tool that runs code with configurable isolation levels.

### Host Parameter

The `host` parameter on the `exec` tool controls where code runs:

| Value | Behavior |
|---|---|
| `auto` (default) | Uses sandbox if enabled, otherwise runs on gateway |
| `sandbox` | Force Docker sandbox (fails if sandbox is not enabled) |
| `gateway` | Execute directly on the gateway host |
| `node` | Execute on a specified node |

### Enabling Docker Sandbox

Add the following block to `openclaw.json`:

```json
{
  "sandbox": {
    "docker": {
      "enabled": true,
      "image": "openclaw-sandbox:bookworm-slim",
      "network": "none"
    }
  }
}
```

**Defaults:** sandbox disabled; when enabled, network is `none` (no outbound connectivity from inside the container).

### Security Features

- **Allowlist mode** — only explicitly whitelisted commands are permitted to run.
- **Per-request approval** — pass `ask: true` on an individual `exec` call to prompt the operator before execution.
- **Gateway/node hardening** — direct (non-sandbox) execution automatically blocks `LD_PRELOAD` injection and PATH override attacks.
- **Crash recovery** — if a sandbox container crashes mid-session, OpenClaw automatically restores the prior execution state on restart.

---

## CoPaw / QwenPaw Sandbox

CoPaw and QwenPaw expose `execute_shell_command` as a built-in tool. Security is rule-based rather than container-based.

### Three Security Guards

**Tool Guard** — pattern-matches commands before execution and auto-blocks known dangerous patterns:
- `rm -rf /` and variants
- Fork bombs (`:(){ :|:& };:`)
- Reverse shell one-liners

Rules are configurable and can be relaxed on a per-agent basis.

**File Access Guard** — restricts access to sensitive filesystem paths:
- Blocks reads/writes to `~/.ssh`, `~/.aws`, and common credential file locations
- Supports configurable allow/deny lists

**Shell Evasion Guard** — detects attempts to hide malicious commands from pattern matching:
- Catches Base64-encoded payloads (`bash -c "$(echo ... | base64 -d)"`)
- Catches hex-escaped commands
- Individual rules can be disabled if they conflict with legitimate use cases

### Configuration

Add a `security` block to `config.json`:

```json
{
  "security": {
    "tool_guard": true,
    "file_guard": true,
    "skill_scanner": true
  }
}
```

### Important Limitation

CoPaw has **no Docker sandbox isolation**. All commands run directly in the worker container process. The guards reduce risk, but the security boundary is the container — the same model as Hermes with the `local` backend.

Choose CoPaw for API-heavy workflows where shell execution is incidental. If code execution is the primary task, prefer Hermes or OpenClaw.

---

## AgentScope Runtime (Advanced)

A standalone sandbox framework maintained by the same organization (`agentscope-ai`).

- **Repo:** `github.com/agentscope-ai/agentscope-runtime`
- **Backends:** Docker, gVisor, BoxLite, Kubernetes, Function Compute
- **API:** `run_ipython_cell(code=...)`, `run_shell_command(command=...)`
- **Status:** Not integrated into HiClaw — available for advanced or custom deployments

Install:

```bash
pip install agentscope-runtime
```

Use this when you need stronger isolation guarantees (gVisor kernel-level sandbox, Kubernetes-native execution) outside the standard HiClaw worker model.

---

## Security Comparison

| Runtime | Isolation Method | Dangerous Commands | Network Control |
|---|---|---|---|
| Hermes (local) | Container boundary | YOLO mode — auto-approve all | Container network policy |
| Hermes (docker) | Docker-in-Docker | Approval gate or YOLO | Configurable per container |
| OpenClaw (sandbox) | Docker container | Allowlist + per-request approval | Default: none |
| OpenClaw (gateway) | No isolation | PATH/LD_PRELOAD override blocked | Full host network access |
| CoPaw | Rule-based guards | Auto-block dangerous patterns | Full host network access |

### Recommendations

- **Highest isolation:** OpenClaw with Docker sandbox (`network: none`) or Hermes with `docker` backend.
- **Lowest friction:** Hermes with `local` backend (default HiClaw setup) — fast, no extra infrastructure, relies on the container boundary.
- **Rule-based only:** CoPaw — acceptable when shell execution is rare and the container network is already restricted at the infrastructure level.
