# OPC Operations Documentation Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create four guides and one MCP template so OPC developers can set up Langfuse observability, Playwright web browsing, local models, and sandbox configuration without touching HiClaw code.

**Architecture:** Five standalone files — each task creates one file and commits. No dependencies between tasks. All content is documentation or YAML templates. Zero code changes.

**Tech Stack:** Markdown (guides), YAML (MCP template)

**Spec:** `docs/superpowers/specs/2026-04-25-opc-docs-pack-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|---|---|
| `docs/langfuse-guide.md` | Langfuse observability: when to use, install, configure with HiClaw |
| `docs/playwright-guide.md` | Playwright web browsing: CLI vs MCP, setup, security |
| `manager/agent/skills/mcp-server-management/references/mcp-playwright.yaml` | Playwright MCP server template for Higress |
| `docs/local-model-guide.md` | Local model setup: Ollama, LM Studio, vLLM |
| `docs/sandbox-guide.md` | Sandbox config: Hermes, OpenClaw, CoPaw native sandboxes |

---

### Task 1: Langfuse Observability Guide

**Files:**
- Create: `docs/langfuse-guide.md`

- [ ] **Step 1: Write the guide**

Create `docs/langfuse-guide.md` with the full content. The guide must cover: decision table (Langfuse vs Hermes Web UI), what Langfuse shows in HiClaw, what it cannot show, Langfuse self-hosted installation (Docker Compose), HiClaw configuration (HICLAW_CMS_* env vars → Langfuse OTLP endpoint), Docker and K8s setup, verification steps, and resource requirements (~500MB-1GB).

Key points to include:
- Lead with the decision table: 1-2 agents → Hermes Web UI; 3+ agents → Langfuse; both compatible
- Langfuse visibility: LLM call details (input/output/tokens/latency), tool call chains, agent session traces, error tracking, cost attribution, latency distribution
- Not visible: agent thinking, Matrix chat content, MinIO file ops
- Install: `docker compose` with PostgreSQL + Langfuse Server + ClickHouse
- HiClaw config: set `HICLAW_CMS_TRACES_ENABLED=true`, `HICLAW_CMS_ENDPOINT=http://localhost:3000/api/public/otel`, `HICLAW_CMS_LICENSE_KEY=<langfuse-public-key>`
- Docker: env vars in installer or `hiclaw-manager.env`
- K8s: `controller.env` in Helm values.yaml
- Verification: check Langfuse dashboard at `http://localhost:3000`

- [ ] **Step 2: Commit**

```bash
git add docs/langfuse-guide.md
git commit --author="吉尔伽美什 <>" -m "docs: add Langfuse observability guide for OPC developers"
```

---

### Task 2: Playwright Web Browsing Guide + MCP Template

**Files:**
- Create: `docs/playwright-guide.md`
- Create: `manager/agent/skills/mcp-server-management/references/mcp-playwright.yaml`

- [ ] **Step 1: Write the guide**

Create `docs/playwright-guide.md` covering:
- Two modes: CLI (recommended, 4x fewer tokens) vs MCP (alternative)
- CLI mode: `npx @playwright/mcp` for agents with filesystem access (Hermes, CoPaw). Agent saves snapshots to disk as YAML, reads only what it needs. ~27K tokens per task vs ~114K for MCP.
- MCP mode: for agents without filesystem access. Register via `setup-mcp-proxy.sh`. Uses accessibility tree snapshots streamed into context.
- When to use which: CLI when agent has filesystem (Claude Code, Hermes, CoPaw); MCP when agent is stateless or remote
- Security: `--allowed-origins` to restrict sites, `--blocked-origins` to block sites. Not a security boundary.
- MCP registration command: `bash skills/mcp-server-management/scripts/setup-mcp-proxy.sh playwright http://localhost:3000/mcp sse`

- [ ] **Step 2: Write the MCP template**

Create `manager/agent/skills/mcp-server-management/references/mcp-playwright.yaml`:

```yaml
# MCP Server template for Playwright browser automation.
# Playwright MCP must be running locally via: npx @playwright/mcp --port 3000
#
# Usage:
#   bash scripts/setup-mcp-proxy.sh playwright http://localhost:3000/mcp sse

server:
  name: playwright
  config: {}

tools:
  - name: browser_navigate
    description: "Navigate to a URL in the browser"

  - name: browser_snapshot
    description: "Take an accessibility snapshot of the current page"

  - name: browser_click
    description: "Click an element on the page by accessibility ref"

  - name: browser_type
    description: "Type text into an input field"

  - name: browser_screenshot
    description: "Take a screenshot of the current page"

  - name: browser_evaluate
    description: "Execute JavaScript in the browser console"
```

- [ ] **Step 3: Commit both files**

```bash
git add docs/playwright-guide.md \
       manager/agent/skills/mcp-server-management/references/mcp-playwright.yaml
git commit --author="吉尔伽美什 <>" -m "docs: add Playwright web browsing guide and MCP template"
```

---

### Task 3: Local Model Guide

**Files:**
- Create: `docs/local-model-guide.md`

- [ ] **Step 1: Write the guide**

Create `docs/local-model-guide.md` covering:
- How HiClaw routes LLM calls: all through Higress AI Gateway → change `HICLAW_OPENAI_BASE_URL` to switch
- Ollama setup: `curl -fsSL https://ollama.com/install.sh | sh`, `ollama pull qwen3:27b`, `ollama serve`, then set `HICLAW_OPENAI_BASE_URL=http://localhost:11434/v1` and `HICLAW_DEFAULT_MODEL=qwen3:27b`
- LM Studio setup: download from lmstudio.ai, load model, start server (default port 1234), set `HICLAW_OPENAI_BASE_URL=http://localhost:1234/v1`
- vLLM setup: `pip install vllm`, `vllm serve qwen3-27b --port 8000`, set `HICLAW_OPENAI_BASE_URL=http://localhost:8000/v1`
- Recommended models table:

| Model | Params | Use Case | VRAM | License |
|---|---|---|---|---|
| Qwen3-27B | 27B | General coding/reasoning | ~22GB | Apache 2.0 |
| Qwen3-8B | 8B | Lightweight tasks | ~8GB | Apache 2.0 |
| bge-m3 | - | Embedding (memory search) | ~1-2GB | MIT |
| Devstral-24B | 24B | Agent coding | ~20GB | - |

- Windows/WSL: Ollama has native Windows installer; LM Studio has native Windows app; vLLM requires WSL2
- Docker deployment: set env vars in installer or `hiclaw-manager.env`
- K8s deployment: set via Helm `controller.env`
- Embedding model: separate from LLM, configured via `HICLAW_EMBEDDING_MODEL`
- Cost comparison: local vs API (agents use 10-50x more tokens than chat)

- [ ] **Step 2: Commit**

```bash
git add docs/local-model-guide.md
git commit --author="吉尔伽美什 <>" -m "docs: add local model setup guide (Ollama, LM Studio, vLLM)"
```

---

### Task 4: Sandbox Configuration Guide

**Files:**
- Create: `docs/sandbox-guide.md`

- [ ] **Step 1: Write the guide**

Create `docs/sandbox-guide.md` covering:
- Overview: each HiClaw runtime has native code execution. HiClaw does not override sandbox settings (bridge.py uses `setdefault`, generator.go doesn't touch exec config).
- Runtime selection table:

| Task Type | Recommended Runtime | Sandbox | Why |
|---|---|---|---|
| Coding / DevOps | Hermes | terminal sandbox (6 backends) | Full IDE-like terminal with PTY, background jobs, crash recovery |
| Content creation | OpenClaw / CoPaw | exec tool / shell command | Lighter weight, sufficient for scripting |
| API-only tasks | Any | No sandbox needed | MCP tools handle external calls |

- Hermes sandbox: edit `~/.hermes/config.yaml` → `terminal.backend` field. Options: local (default in HiClaw), docker, ssh, daytona, singularity, modal. Via hermes-web-ui Settings page or direct YAML edit. `HERMES_YOLO_MODE=1` auto-set by HiClaw entrypoint (bypasses approval gate in container).
- OpenClaw sandbox: `exec` tool with `host` parameter. `auto` (default): uses sandbox if enabled, gateway otherwise. `sandbox`: force Docker sandbox (must enable in config). `gateway`: execute on gateway host. Docker sandbox setup: set `sandbox.docker.enabled: true` in openclaw.json. Default: no network in sandbox.
- CoPaw/QwenPaw sandbox: `execute_shell_command` built-in tool. Protected by Tool Guard (blocks dangerous commands like `rm -rf /`, fork bombs, reverse shells), File Access Guard (restricts sensitive paths like `~/.ssh`), Shell Evasion Guard (detects obfuscation). No Docker isolation — security is rule-based.
- AgentScope Runtime: standalone sandbox framework at `github.com/agentscope-ai/agentscope-runtime`. Supports Docker/gVisor/BoxLite/K8s. Not integrated in HiClaw but available for advanced use. Install: `pip install agentscope-runtime`.
- Security comparison table:

| Runtime | Isolation | Dangerous Command Handling |
|---|---|---|
| Hermes | Container-level (HiClaw worker is the boundary) | HERMES_YOLO_MODE=1 bypasses approval |
| OpenClaw | Optional Docker sandbox | Allowlist mode, per-request approval |
| CoPaw | Rule-based guards (no container) | Auto-block dangerous patterns |

- [ ] **Step 2: Commit**

```bash
git add docs/sandbox-guide.md
git commit --author="吉尔伽美什 <>" -m "docs: add sandbox configuration guide for Hermes/OpenClaw/CoPaw"
```

---

## Summary

| Task | File(s) | Description |
|---|---|---|
| 1 | langfuse-guide.md | Langfuse observability: decision table, install, config |
| 2 | playwright-guide.md + mcp-playwright.yaml | Playwright: CLI vs MCP, template |
| 3 | local-model-guide.md | Local models: Ollama, LM Studio, vLLM |
| 4 | sandbox-guide.md | Sandbox: Hermes, OpenClaw, CoPaw native config |
