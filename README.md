# HiClaw

**Open-source Agent Teams system with IM-based multi-Agent collaboration and human-in-the-loop oversight.**

HiClaw lets you deploy a team of AI Agents that communicate via instant messaging (Matrix protocol), coordinate tasks through a centralized file system, and are fully observable and controllable by human administrators.

## Key Features

- **Agent Teams**: Manager Agent coordinates multiple Worker Agents to complete complex tasks
- **Human in the Loop**: All Agent communication happens in Matrix Rooms where humans can observe and intervene at any time
- **AI Gateway**: Unified LLM and MCP Server access through Higress, with per-Worker credential management
- **Stateless Workers**: Workers load all config from centralized storage -- destroy and recreate freely
- **MCP Integration**: External tools (GitHub, etc.) accessed via MCP Servers with centralized credential management
- **Open Source**: Built on Higress, Tuwunel, MinIO, OpenClaw, and Element Web

## Quick Start

See **[docs/quickstart.md](docs/quickstart.md)** for a step-by-step guide from zero to a working Agent team.

### Prerequisites

- Docker installed on your machine
- An LLM API key (e.g., Qwen, OpenAI)
- (Optional) A GitHub Personal Access Token for GitHub collaboration features

### 30-Second Overview

```bash
# Option A: Using Make (for developers)
git clone https://github.com/higress-group/hiclaw.git && cd hiclaw
HICLAW_LLM_API_KEY="sk-xxx" make install

# Option B: One-line install (no git clone needed)
curl -fsSL https://raw.githubusercontent.com/higress-group/hiclaw/main/install/hiclaw-install.sh | bash -s manager

# Then open Element Web and chat with your Manager Agent
# http://matrix-client-local.hiclaw.io:8080

# Or send tasks via CLI
make replay TASK="Create a Worker named alice for frontend development. Create it directly."
```

## Architecture

```
┌─────────────────────────────────────────────┐
│         hiclaw-manager-agent                │
│  Higress │ Tuwunel │ MinIO │ Element Web    │
│  Manager Agent (OpenClaw)                   │
└──────────────────┬──────────────────────────┘
                   │ Matrix + HTTP Files
┌──────────────────┴──────┐  ┌────────────────┐
│  hiclaw-worker-agent    │  │  hiclaw-worker │
│  Worker Alice (OpenClaw)│  │  Worker Bob    │
└─────────────────────────┘  └────────────────┘
```

## Multi-Agent Architecture: HiClaw vs OpenClaw Native

HiClaw is built on top of [OpenClaw](https://github.com/nicepkg/openclaw) (the open-source agent framework). OpenClaw provides native multi-agent support through its `agents.list` and `bindings` configuration, where multiple agents run as isolated "brains" inside a single Gateway process. HiClaw takes a fundamentally different approach by deploying agents as independent containers coordinated via IM and a centralized gateway.

| Dimension | OpenClaw Native | HiClaw |
|---|---|---|
| **Deployment model** | Single process, multiple agents | Distributed containers (one per agent) |
| **Agent topology** | Flat peers, routing by channel/account | Hierarchical Manager + Workers |
| **Communication** | Internal message bus (`sessions_send/spawn`) | Matrix Rooms (human always present) |
| **Human oversight** | Optional (humans interact via IM channels) | Built-in (human in every Room, full visibility) |
| **LLM access** | Each agent configures its own model/API key | Unified AI Gateway (Higress) with per-agent auth |
| **External tools** | Each agent holds its own credentials | Centralized MCP Server with credential isolation |
| **State management** | Per-agent local directories + sessions | Centralized file system (MinIO) with stateless Workers |
| **Scaling** | Vertical (more agents in one process) | Horizontal (add Worker containers, even cross-machine) |
| **Fault isolation** | Shared process (one crash affects all) | Container-level isolation (Worker crash is self-contained) |
| **Agent lifecycle** | Static config, restart to change | Dynamic creation/destruction at runtime by Manager |
| **Skill management** | Per-agent workspace skills (manual file management) | Centralized skill distribution via MinIO, Manager-controlled per-Worker |
| **Self-improvement** | No built-in mechanism | Manager reviews Worker performance, evolves team skills over time |

### Key Advantages of HiClaw

- **Fully Automated Multi-Agent Lifecycle**: The Manager Agent handles the entire Worker lifecycle autonomously -- account registration, identity configuration (SOUL.md), gateway credential provisioning, skill assignment, task dispatch, and progress monitoring. In OpenClaw native mode, each of these steps requires manual configuration across multiple files and a process restart. HiClaw turns multi-agent orchestration from a manual config task into a conversational request: "Create a Worker named alice for frontend development."

- **Self-Improving Agent Team**: HiClaw's design includes two built-in extension skills that make the team better over time:
  - **Worker Experience Management**: After each task, the Manager reviews Worker performance, maintains per-Worker experience profiles with skill-level scoring, and uses this data to intelligently assign future tasks to the best-suited Worker.
  - **Skill Evolution Management**: The Manager analyzes patterns across completed tasks, drafts new skills or skill improvements, submits them for human review, and validates them through simulated tasks -- creating a continuous improvement loop for the entire team's capabilities.

  These mechanisms are impractical to replicate in OpenClaw's flat peer model, where there is no central coordinator to collect cross-agent performance data or manage skill evolution.

- **Human-in-the-Loop by Design**: Every Matrix Room includes the human administrator alongside Manager and Worker. All task assignments, progress updates, and results are visible and interruptible in real-time -- no hidden agent-to-agent communication.

- **Distributed Fault Isolation**: Each agent runs in its own container. A Worker crash or hang does not affect the Manager or other Workers. Workers can be individually restarted, replaced, or migrated to different machines without downtime.

- **Credential Isolation via Gateway**: External API credentials (GitHub PAT, GitLab tokens, etc.) are stored only in the Higress MCP Server configuration. Workers access these services through their own consumer key-auth tokens -- they never see the actual credentials. The Manager can grant or revoke tool access per-Worker at any time.

- **Stateless Workers**: All Worker configuration, task briefs, and results are stored in MinIO. Workers load everything from centralized storage on startup. Destroy a Worker and recreate it with the same name -- it resumes with full context.

- **Dynamic Team Scaling**: The Manager can create new Workers on-demand based on task requirements (directly via Docker/Podman socket or by providing a `docker run` command). No need to restart the system or edit configuration files.

- **Unified Access Control**: Higress provides a single control plane for all resource access. The Manager controls which LLM routes, file system paths, and MCP Server tools each Worker can use -- all through consumer-level authorization at the gateway layer.

## Documentation

| Document | Description |
|----------|-------------|
| [docs/quickstart.md](docs/quickstart.md) | End-to-end quickstart guide with verification checkpoints |
| [docs/architecture.md](docs/architecture.md) | System architecture and component overview |
| [docs/manager-guide.md](docs/manager-guide.md) | Manager setup and configuration |
| [docs/worker-guide.md](docs/worker-guide.md) | Worker deployment and troubleshooting |
| [docs/development.md](docs/development.md) | Contributing guide and local development |

## Build & Test

```bash
# Build all images
make build

# Build + run all integration tests (10 test cases)
make test

# Run specific tests only
make test TEST_FILTER="01 02 03"

# Run tests without rebuilding images
make test SKIP_BUILD=1

# Quick smoke test (test-01 only)
make test-quick
```

## Install / Uninstall / Replay

```bash
# Install Manager locally (builds images + interactive setup)
HICLAW_LLM_API_KEY="sk-xxx" make install

# Install without rebuilding images
HICLAW_LLM_API_KEY="sk-xxx" SKIP_BUILD=1 make install

# Send a task to Manager via CLI
make replay TASK="Create a Worker named alice for frontend development"

# View latest replay conversation log
make replay-log

# Run tests against installed Manager (no rebuild, no new container)
make test-installed

# Uninstall everything (Manager + Workers + volume + env file)
make uninstall
```

## Push & Release

```bash
# Push multi-arch images (amd64 + arm64) to registry
make push VERSION=0.1.0 REGISTRY=ghcr.io REPO=higress-group/hiclaw

# Clean up containers and images
make clean

# Show all targets
make help
```

## Project Structure

```
hiclaw/
├── manager/           # Manager Agent container (all-in-one: Higress + Tuwunel + MinIO + Element Web + OpenClaw)
├── worker/            # Worker Agent container (lightweight: OpenClaw + mc + mcporter)
├── install/           # One-click installation scripts
├── scripts/           # Utility scripts (replay-task.sh)
├── hack/              # Maintenance scripts (mirror-images.sh)
├── tests/             # Automated integration tests (10 test cases)
├── .github/workflows/ # CI/CD pipelines
├── docs/              # User documentation
└── design/            # Internal design documents
```

See [AGENTS.md](AGENTS.md) for a detailed codebase navigation guide.

## License

Apache License 2.0
