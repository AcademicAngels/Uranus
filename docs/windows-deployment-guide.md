# Uranus Windows Deployment Guide

Deploy HiClaw (Uranus fork) with Hermes-as-Manager on Windows Docker Desktop + WSL.

## Prerequisites

- Windows 10/11 with WSL2 enabled
- Docker Desktop with WSL Integration enabled
- `docker login` completed (for pulling/pushing images)
- Git clone of Uranus repo

## Step 1: Build Images

```bash
# In WSL terminal, navigate to project
cd /mnt/c/path/to/Uranus

# Build all images (first time)
bash scripts/build-and-push.sh

# Or build only what changed (after upstream follow)
bash scripts/build-and-push.sh hermes

# Check which images need rebuild
bash scripts/build-and-push.sh --check
```

If Docker Hub is slow, use China mirrors:

```bash
DOCKERHUB_MIRROR_PREFIX=m.daocloud.io/docker.io \
bash scripts/build-and-push.sh
```

## Step 2: Install HiClaw

```bash
# Get the version tag from build output
export VERSION=dev-$(git rev-parse --short HEAD)
export DOCKER_NS=tingchaopavilion

# Non-interactive install with OpenClaw Manager and Hermes Workers
HICLAW_NON_INTERACTIVE=1 \
HICLAW_MANAGER_RUNTIME=openclaw \
HICLAW_DEFAULT_WORKER_RUNTIME=hermes \
HICLAW_LLM_PROVIDER=openai-compatible \
HICLAW_LLM_API_KEY="sk-your-api-key" \
HICLAW_OPENAI_BASE_URL="https://api.openai.com/v1" \
HICLAW_DEFAULT_MODEL="gpt-4o" \
HICLAW_INSTALL_EMBEDDED_IMAGE=docker.io/${DOCKER_NS}/uranus-embedded:${VERSION} \
HICLAW_INSTALL_CONTROLLER_IMAGE=docker.io/${DOCKER_NS}/uranus-controller:${VERSION} \
HICLAW_INSTALL_MANAGER_IMAGE=docker.io/${DOCKER_NS}/uranus-manager:${VERSION} \
HICLAW_INSTALL_HERMES_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION} \
HICLAW_INSTALL_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-worker:${VERSION} \
HICLAW_INSTALL_COPAW_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-copaw-worker:${VERSION} \
bash install/hiclaw-install.sh
```

For local models (Ollama/LM Studio):

```bash
# Start Ollama first
ollama serve &
ollama pull qwen3:27b

# Then install with local model
HICLAW_NON_INTERACTIVE=1 \
HICLAW_MANAGER_RUNTIME=openclaw \
HICLAW_DEFAULT_WORKER_RUNTIME=hermes \
HICLAW_LLM_PROVIDER=openai-compatible \
HICLAW_LLM_API_KEY="ollama" \
HICLAW_OPENAI_BASE_URL="http://host.docker.internal:11434/v1" \
HICLAW_DEFAULT_MODEL="qwen3:27b" \
HICLAW_INSTALL_EMBEDDED_IMAGE=docker.io/${DOCKER_NS}/uranus-embedded:${VERSION} \
HICLAW_INSTALL_CONTROLLER_IMAGE=docker.io/${DOCKER_NS}/uranus-controller:${VERSION} \
HICLAW_INSTALL_MANAGER_IMAGE=docker.io/${DOCKER_NS}/uranus-manager:${VERSION} \
bash install/hiclaw-install.sh
```

## Step 3: Access Services

After installation, these ports are available:

| Service | URL | Purpose |
|---------|-----|---------|
| Element Web | http://localhost:18088 | Matrix chat (talk to agents) |
| Hermes Web UI | Worker exposed port | Agent config, token stats, cron jobs |
| Higress Console | http://localhost:18001 | Gateway management |
| MinIO Console | http://localhost:9001 | File browser |

## Step 4: Verify

```bash
# Check containers are running
docker ps | grep hiclaw

# Check Manager is OpenClaw
docker logs hiclaw-manager 2>&1 | grep "OpenClaw Manager"

# Check hermes-web-ui is running after creating a Hermes Worker
docker logs hiclaw-worker-<name> 2>&1 | grep "hermes-web-ui"
```

## Updating After Upstream Follow

```bash
# 1. Pull upstream changes
git fetch upstream
git rebase upstream/main

# 2. Check which images need rebuild
bash scripts/build-and-push.sh --check

# 3. Rebuild only changed images
bash scripts/build-and-push.sh hermes   # if hermes/ changed
bash scripts/build-and-push.sh copaw    # if copaw/ changed

# 4. Upgrade the installation
HICLAW_UPGRADE=1 \
HICLAW_INSTALL_EMBEDDED_IMAGE=docker.io/${DOCKER_NS}/uranus-embedded:${VERSION} \
HICLAW_INSTALL_HERMES_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION} \
bash install/hiclaw-install.sh
```

## Optional: Obsidian Vault Sync

```bash
# Copy scaffold to your Obsidian vault location
cp -r shared/vault-scaffold/ /mnt/c/Users/YourName/obsidian-hiclaw-vault/

# Set up bidirectional sync (run in background)
mc alias set hiclaw http://localhost:9000 minioadmin minioadmin
mc mirror --watch /mnt/c/Users/YourName/obsidian-hiclaw-vault/ hiclaw/hiclaw-storage/shared/vault/
```

## Optional: Langfuse Observability

Only needed for 3+ agent collaboration. See `docs/langfuse-guide.md`.

## Troubleshooting

### Port 6060 not accessible

Hermes Web UI runs inside Hermes Worker containers. If port 6060 isn't exposed, check the Worker container:

```bash
docker inspect hiclaw-worker-<name> | grep -A5 "Ports"
```

Expose port 6060 through the Worker CRD `expose` field when you need browser access to that Worker's Hermes Web UI.

### "hermes" not available as Manager runtime

This is expected. Hermes is supported as a Worker runtime; Manager runtime is `openclaw` or `copaw`.

### Docker Hub timeout

Use China mirrors:

```bash
DOCKERHUB_MIRROR_PREFIX=m.daocloud.io/docker.io bash scripts/build-and-push.sh
```

Or pre-pull the Node 23 image:

```bash
docker pull m.daocloud.io/docker.io/library/node:23-slim
docker tag m.daocloud.io/docker.io/library/node:23-slim node:23-slim
```
