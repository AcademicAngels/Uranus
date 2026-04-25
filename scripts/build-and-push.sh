#!/bin/bash
# Uranus Build & Push Script
#
# For Windows Docker Desktop + WSL Ubuntu
# Builds all images needed for Hermes-as-Manager deployment
#
# Prerequisites:
#   - Docker Desktop with WSL Integration enabled
#   - docker login completed
#   - Project at /mnt/c/.../Uranus (or any WSL-accessible path)
#
# Usage:
#   cd /path/to/Uranus
#   bash scripts/build-and-push.sh
#
# China/proxy build examples:
#   DOCKER_BUILD_ARGS="--build-arg APT_MIRROR=mirrors.aliyun.com --build-arg NPM_REGISTRY=https://registry.npmmirror.com/" \
#   bash scripts/build-and-push.sh
#
#   DOCKERHUB_MIRROR_PREFIX=m.daocloud.io/docker.io bash scripts/build-and-push.sh
#
#   NODE_IMAGE=registry.example.com/library/node:23-slim bash scripts/build-and-push.sh
#
#   DOCKER_BUILD_ARGS="--build-arg HTTP_PROXY=http://host.docker.internal:1087 --build-arg HTTPS_PROXY=http://host.docker.internal:1087" \
#   bash scripts/build-and-push.sh

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────
DOCKER_NS="${DOCKER_NS:-tingchaopavilion}"
VERSION="${VERSION:-dev-$(git rev-parse --short HEAD)}"
HIGRESS_REGISTRY="${HIGRESS_REGISTRY:-higress-registry.cn-hangzhou.cr.aliyuncs.com}"
DOCKERHUB_MIRROR_PREFIX="${DOCKERHUB_MIRROR_PREFIX:-m.daocloud.io/docker.io}"
NODE_IMAGE="${NODE_IMAGE:-${DOCKERHUB_MIRROR_PREFIX}/library/node:23-slim}"
DOCKER_BUILD_ARGS="${DOCKER_BUILD_ARGS:-}"
export DOCKER_BUILDKIT=1

echo "============================================"
echo "  Uranus Build & Push"
echo "  Namespace: ${DOCKER_NS}"
echo "  Version:   ${VERSION}"
echo "  Registry:  ${HIGRESS_REGISTRY}"
echo "  HubMirror: ${DOCKERHUB_MIRROR_PREFIX}"
echo "  Node:      ${NODE_IMAGE}"
echo "============================================"
if [ -n "${DOCKER_BUILD_ARGS}" ]; then
    echo "  Extra build args: ${DOCKER_BUILD_ARGS}"
fi
echo ""

# ── Step 1: Build hiclaw-controller ──────────────────────────────────────
# Prerequisite for embedded image. Contains controller binary, hiclaw CLI,
# kube-apiserver, CRDs, and agent config templates.
echo "[1/5] Building hiclaw-controller..."

rm -rf ./hiclaw-controller/agent
cp -r ./manager/agent ./hiclaw-controller/agent

docker build \
    ${DOCKER_BUILD_ARGS} \
    --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
    -t hiclaw/hiclaw-controller:${VERSION} \
    ./hiclaw-controller

rm -rf ./hiclaw-controller/agent

echo "  ✓ hiclaw-controller built"

# ── Step 2: Build embedded (infrastructure) ──────────────────────────────
# All-in-one container: Tuwunel (Matrix) + MinIO + Higress + Element Web +
# Controller + kube-apiserver. This is the deployment entry point.
# Does NOT contain the Manager Agent — Controller creates it dynamically.
echo "[2/5] Building embedded (infrastructure)..."

docker build \
    ${DOCKER_BUILD_ARGS} \
    --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
    --build-arg HICLAW_CONTROLLER_IMAGE=hiclaw/hiclaw-controller:${VERSION} \
    -f ./hiclaw-controller/Dockerfile.embedded \
    -t hiclaw/hiclaw-embedded:${VERSION} \
    .

docker tag hiclaw/hiclaw-embedded:${VERSION} \
    docker.io/${DOCKER_NS}/uranus-embedded:${VERSION}
docker push docker.io/${DOCKER_NS}/uranus-embedded:${VERSION}

echo "  ✓ embedded built & pushed"

# ── Step 3: Build hermes-worker ──────────────────────────────────────────
# Used as BOTH Manager (HICLAW_MANAGER_RUNTIME=hermes) and Worker.
# Contains: hermes-agent v0.10.0, mcpvault, hermes-web-ui, mcporter,
# skills CLI, MinIO client, hiclaw CLI, Matrix adapter shim.
echo "[3/5] Building hermes-worker (Manager + Worker)..."

docker build \
    ${DOCKER_BUILD_ARGS} \
    --build-context shared=./shared/lib \
    --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
    --build-arg NODE_IMAGE="${NODE_IMAGE}" \
    --build-arg HICLAW_CONTROLLER_IMAGE=hiclaw/hiclaw-controller:${VERSION} \
    -t hiclaw/hiclaw-hermes-worker:${VERSION} \
    ./hermes

docker tag hiclaw/hiclaw-hermes-worker:${VERSION} \
    docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION}
docker push docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION}

echo "  ✓ hermes-worker built & pushed (includes hermes-web-ui)"

# ── Step 4: Build copaw-worker ───────────────────────────────────────────
# Python (AgentScope/QwenPaw) Worker runtime.
# Contains: CoPaw, mcpvault, mcporter, skills CLI, ReMe (lazy-loaded).
echo "[4/5] Building copaw-worker..."

docker build \
    ${DOCKER_BUILD_ARGS} \
    --build-context shared=./shared/lib \
    --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
    --build-arg HICLAW_CONTROLLER_IMAGE=hiclaw/hiclaw-controller:${VERSION} \
    -t hiclaw/hiclaw-copaw-worker:${VERSION} \
    ./copaw

docker tag hiclaw/hiclaw-copaw-worker:${VERSION} \
    docker.io/${DOCKER_NS}/uranus-copaw-worker:${VERSION}
docker push docker.io/${DOCKER_NS}/uranus-copaw-worker:${VERSION}

echo "  ✓ copaw-worker built & pushed"

# ── Step 5: Build openclaw-worker ────────────────────────────────────────
# Node.js (OpenClaw) Worker runtime.
# Requires openclaw-base as build dependency.
echo "[5/5] Building openclaw-worker..."

# Build openclaw-base first (shared base for OpenClaw runtime)
docker build \
    ${DOCKER_BUILD_ARGS} \
    --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
    -t hiclaw/openclaw-base:${VERSION} \
    ./openclaw-base

docker build \
    ${DOCKER_BUILD_ARGS} \
    --build-context shared=./shared/lib \
    --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
    --build-arg OPENCLAW_BASE_IMAGE=hiclaw/openclaw-base:${VERSION} \
    -t hiclaw/hiclaw-worker:${VERSION} \
    ./worker

docker tag hiclaw/hiclaw-worker:${VERSION} \
    docker.io/${DOCKER_NS}/uranus-worker:${VERSION}
docker push docker.io/${DOCKER_NS}/uranus-worker:${VERSION}

echo "  ✓ openclaw-worker built & pushed"

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  All images built and pushed!"
echo "============================================"
echo ""
echo "Deploy with these environment variables:"
echo ""
cat <<EOF
# ── Uranus Deployment Config ──
HICLAW_VERSION=${VERSION}

# Infrastructure (embedded = Tuwunel + MinIO + Higress + Element + Controller)
HICLAW_INSTALL_MANAGER_IMAGE=docker.io/${DOCKER_NS}/uranus-embedded:${VERSION}

# Manager runtime: hermes (with Web UI on port 6060)
HICLAW_MANAGER_RUNTIME=hermes
HICLAW_INSTALL_HERMES_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION}

# Worker images
HICLAW_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-worker:${VERSION}
HICLAW_COPAW_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-copaw-worker:${VERSION}
HICLAW_HERMES_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION}
EOF

echo ""
echo "Quick install (non-interactive):"
echo ""
cat <<'INSTALLEOF'
HICLAW_NON_INTERACTIVE=1 \
HICLAW_MANAGER_RUNTIME=hermes \
HICLAW_LLM_API_KEY="sk-xxx" \
HICLAW_INSTALL_MANAGER_IMAGE=docker.io/${DOCKER_NS}/uranus-embedded:${VERSION} \
HICLAW_INSTALL_HERMES_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION} \
bash install/hiclaw-install.sh
INSTALLEOF
