# OPC Operations Documentation Pack Design

**Date:** 2026-04-25
**Status:** Draft
**Scope:** Four documentation files for OPC developers — Langfuse, Playwright, local models, sandbox configuration

## Problem Statement

HiClaw already has the infrastructure for observability (OTEL), web browsing (MCP), local models (OPENAI_BASE_URL), and sandboxed code execution (native per-runtime). OPC developers lack documentation on how to use these capabilities.

## Constraints

- Zero code changes — documentation and one MCP template only
- Zero fork risk — no upstream files modified
- All docs in English (consistent with existing project docs)

## Design

### 1. Langfuse Observability Guide

**File:** `docs/langfuse-guide.md`

Covers:

#### When to Use Langfuse vs Hermes Web UI

| Scenario | Recommended | Reason |
|---|---|---|
| 1-2 Agents, personal use | **Hermes Web UI** (built-in) | Zero setup, per-agent token/cost tracking already included |
| 3+ Agents collaborating | **Langfuse** (self-hosted) | Cross-agent trace visibility, global cost attribution, Manager→Worker call chain |
| Both | Compatible | Hermes Web UI for per-agent dashboard, Langfuse for global orchestration view |

The guide must lead with this decision table so OPC developers don't install Langfuse unnecessarily.

#### What Langfuse Shows You in HiClaw

HiClaw's OTEL traces capture the following. Once routed to Langfuse, OPC developers can see:

| Visibility | What You See | OPC Value |
|---|---|---|
| **LLM 调用详情** | 每次 LLM API 调用的 input/output、model name、token count、latency | 定位哪个 Agent 消耗了多少 token，优化成本 |
| **工具调用链** | MCP tool calls (GitHub, mcpvault, etc.) 的参数和返回值 | 调试 Agent 为什么选了错误的工具或参数 |
| **Agent 会话轨迹** | Manager→Worker 任务分配和执行的完整 trace span 树 | 理解多 Agent 协作流程中的瓶颈 |
| **错误追踪** | 失败的 LLM 调用、超时、工具调用异常 | 快速定位"Agent 卡住了"的根因 |
| **成本归因** | 按 Agent/Session/Model 维度的 token 成本估算 | 决定哪些任务该用便宜模型、哪些需要强模型 |
| **延迟分布** | P50/P95/P99 响应时间 | 发现慢查询，优化 Agent 响应速度 |

**不能看到的**：Agent 内部推理过程（thinking）、Matrix 聊天消息内容（不走 OTEL）、MinIO 文件操作细节。

#### Installation & Configuration

- **Langfuse 安装**：Docker Compose 部署（PostgreSQL + Langfuse Server + ClickHouse），提供完整 `docker compose` 命令和 `.env` 配置
- HiClaw already uses standard OTEL env vars — zero HiClaw code changes needed
- Configuration: map `HICLAW_CMS_*` env vars to Langfuse OTLP endpoint
  - Docker 部署：安装脚本环境变量
  - K8s/Helm：通过 `controller.env` 传递
- Verification: check traces appear in Langfuse dashboard
- 资源需求说明（PostgreSQL + Langfuse 约 500MB-1GB 额外内存）

### 2. Playwright Web Browsing Guide

**File:** `docs/playwright-guide.md`
**Template:** `manager/agent/skills/mcp-server-management/references/mcp-playwright.yaml`

Covers:
- CLI mode (recommended): `npx playwright` — 4x fewer tokens than MCP mode
- MCP mode (alternative): register via `setup-mcp-proxy.sh`
- MCP YAML template for Higress registration
- When to use CLI vs MCP (agents with filesystem access → CLI; agents without → MCP)
- Security: `--allowed-origins` and `--blocked-origins`

### 3. Local Model Guide

**File:** `docs/local-model-guide.md`

Covers:
- HiClaw routes all LLM calls through Higress AI Gateway — change endpoint to switch models
- Ollama setup: install, pull model, serve, configure `HICLAW_OPENAI_BASE_URL`
- LM Studio setup: same pattern, different port
- vLLM setup: for production/GPU environments
- Recommended models: Qwen3-27B (SWE-bench 77.2%), bge-m3 (embedding)
- VRAM requirements table
- Windows/WSL considerations
- Docker vs K8s configuration

### 4. Sandbox Configuration Guide

**File:** `docs/sandbox-guide.md`

Covers:
- Each runtime has native code execution — HiClaw doesn't override
- Hermes: `config.yaml` → `terminal.backend` (local/Docker/SSH/Daytona/Singularity/Modal)
- OpenClaw: `exec` tool with `host` parameter (sandbox/gateway/node/auto), Docker sandbox setup
- CoPaw/QwenPaw: `execute_shell_command` with Tool Guard, File Access Guard, Shell Evasion Guard
- AgentScope Runtime: standalone sandbox framework (Docker/gVisor/BoxLite/K8s) — available but not integrated in HiClaw
- Choosing the right runtime for your task type

## Files to Create

| File | Type |
|------|------|
| `docs/langfuse-guide.md` | Documentation |
| `docs/playwright-guide.md` | Documentation |
| `docs/local-model-guide.md` | Documentation |
| `docs/sandbox-guide.md` | Documentation |
| `manager/agent/skills/mcp-server-management/references/mcp-playwright.yaml` | MCP template |

## What This Design Does NOT Include

- No code changes to any runtime, bridge, or controller
- No Helm chart changes
- No install script changes
- No Dockerfile changes
- No CRD changes
