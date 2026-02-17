# hiclaw-manager-agent

All-in-one Manager Agent container. Includes:

- **Higress AI Gateway** (port 8080 gateway, 8001 console): LLM proxy, MCP Server hosting, consumer auth
- **Tuwunel Matrix Server** (port 6167): Agent IM communication
- **MinIO** (port 9000 API, 9001 console): Centralized HTTP file system
- **Element Web** (via Nginx on port 8088, proxied through Higress): Browser-based IM client
- **Manager Agent** (OpenClaw): Coordinates Workers, manages credentials, assigns tasks
- **mc mirror**: Bidirectional file sync between MinIO and local filesystem

## Build

```bash
# Via Makefile (recommended)
make build-manager

# Or directly
docker build -t hiclaw/manager-agent:latest .
```

## Run

Use the installation script instead of running directly:

```bash
../install/hiclaw-install.sh manager
```

## Directory Structure

```
manager/
├── Dockerfile              # Multi-stage build
├── supervisord.conf        # Process orchestration (priority-ordered)
├── scripts/                # Startup scripts (one per component)
│   ├── base.sh             # Shared utilities
│   ├── start-*.sh          # Component startup scripts
│   └── setup-higress.sh    # Higress route/consumer/MCP init
├── configs/
│   ├── manager-openclaw.json.tmpl  # OpenClaw config template
│   ├── mcp-github.yaml    # GitHub MCP Server config
│   └── storage-init/      # Initial MinIO directory structure
│       └── agents/manager/ # Manager SOUL.md, HEARTBEAT.md, Skills
└── tests/
    └── smoke-test.sh       # Post-startup health check
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HICLAW_ADMIN_USER` | Yes | - | Human admin Matrix username |
| `HICLAW_ADMIN_PASSWORD` | Yes | - | Human admin password |
| `HICLAW_MANAGER_PASSWORD` | Yes | - | Manager Agent Matrix password |
| `HICLAW_REGISTRATION_TOKEN` | Yes | - | Tuwunel registration token |
| `HICLAW_MATRIX_DOMAIN` | No | `matrix-local.hiclaw.io:8080` | Matrix server domain |
| `HICLAW_MATRIX_CLIENT_DOMAIN` | No | `matrix-client-local.hiclaw.io` | Element Web domain |
| `HICLAW_AI_GATEWAY_DOMAIN` | No | `llm-local.hiclaw.io` | AI Gateway domain |
| `HICLAW_FS_DOMAIN` | No | `fs-local.hiclaw.io` | HTTP file system domain |
| `HICLAW_LLM_PROVIDER` | Yes | - | LLM provider name |
| `HICLAW_DEFAULT_MODEL` | Yes | - | Default LLM model ID |
| `HICLAW_LLM_API_KEY` | Yes | - | LLM API key |
| `HICLAW_MINIO_USER` | Yes | - | MinIO root user |
| `HICLAW_MINIO_PASSWORD` | Yes | - | MinIO root password |
| `HICLAW_MANAGER_GATEWAY_KEY` | Yes | - | Manager's Higress consumer key |
| `HICLAW_GITHUB_TOKEN` | No | - | GitHub PAT for MCP Server |
