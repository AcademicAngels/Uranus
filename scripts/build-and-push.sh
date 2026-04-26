#!/bin/bash
# Uranus Build & Push Script
#
# Builds and pushes Docker images for OpenClaw Manager + Hermes Worker deployment.
# Supports selective builds, remote tag checks, and China mirror proxies.
#
# Usage:
#   bash scripts/build-and-push.sh              # build all
#   bash scripts/build-and-push.sh hermes       # build only hermes-worker
#   bash scripts/build-and-push.sh copaw hermes # build copaw + hermes
#   bash scripts/build-and-push.sh --check      # check which images need rebuild
#
# Available targets: controller, manager, manager-copaw, embedded, hermes, copaw, openclaw
#
# Environment variables:
#   DOCKER_NS              DockerHub namespace (default: tingchaopavilion)
#   VERSION                Image tag (default: dev-<short-sha>)
#   FORCE_BUILD            Set to 1 to skip remote tag check (default: 0)
#   SKIP_PUSH              Set to 1 to build only, no push (default: 0)
#   HIGRESS_REGISTRY       China mirror for Higress base images
#   DOCKERHUB_MIRROR_PREFIX  Mirror prefix for Docker Hub pulls
#   NODE_IMAGE             Node.js 23 image for hermes-web-ui build stage
#   DOCKER_BUILD_ARGS      Extra docker build args (e.g., proxy settings)

set -euo pipefail

DOCKER_NS="${DOCKER_NS:-tingchaopavilion}"
VERSION="${VERSION:-dev-$(git rev-parse --short HEAD)}"
FORCE_BUILD="${FORCE_BUILD:-0}"
SKIP_PUSH="${SKIP_PUSH:-0}"
HIGRESS_REGISTRY="${HIGRESS_REGISTRY:-higress-registry.cn-hangzhou.cr.aliyuncs.com}"
DOCKERHUB_MIRROR_PREFIX="${DOCKERHUB_MIRROR_PREFIX:-m.daocloud.io/docker.io}"
NODE_IMAGE="${NODE_IMAGE:-${DOCKERHUB_MIRROR_PREFIX}/library/node:23-slim}"
DOCKER_BUILD_ARGS="${DOCKER_BUILD_ARGS:-}"
export DOCKER_BUILDKIT=1

remote_tag_exists() {
    local image="$1"
    if [ "${FORCE_BUILD}" = "1" ]; then
        return 1
    fi
    docker manifest inspect "${image}" >/dev/null 2>&1
}

tag_and_push() {
    local local_tag="$1"
    local remote_tag="$2"
    docker tag "${local_tag}" "${remote_tag}"
    if [ "${SKIP_PUSH}" = "1" ]; then
        echo "  (skip push: SKIP_PUSH=1)"
    else
        docker push "${remote_tag}"
    fi
}

controller_image_ref() {
    local local_ref="hiclaw/hiclaw-controller:${VERSION}"
    if docker image inspect "${local_ref}" >/dev/null 2>&1; then
        echo "${local_ref}"
    else
        echo "docker.io/${DOCKER_NS}/uranus-controller:${VERSION}"
    fi
}

build_controller() {
    local remote="docker.io/${DOCKER_NS}/uranus-controller:${VERSION}"
    if remote_tag_exists "${remote}"; then
        echo "[controller] ${VERSION} already exists remotely, skipping."
        return 0
    fi
    echo "[controller] Building..."
    rm -rf ./hiclaw-controller/agent
    cp -r ./manager/agent ./hiclaw-controller/agent
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        -t hiclaw/hiclaw-controller:${VERSION} \
        ./hiclaw-controller
    rm -rf ./hiclaw-controller/agent
    tag_and_push "hiclaw/hiclaw-controller:${VERSION}" "${remote}"
    echo "  done."
}

build_embedded() {
    local remote="docker.io/${DOCKER_NS}/uranus-embedded:${VERSION}"
    if remote_tag_exists "${remote}"; then
        echo "[embedded] ${VERSION} already exists remotely, skipping."
        return 0
    fi
    echo "[embedded] Building..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(controller_image_ref)" \
        -f ./hiclaw-controller/Dockerfile.embedded \
        -t hiclaw/hiclaw-embedded:${VERSION} \
        .
    tag_and_push "hiclaw/hiclaw-embedded:${VERSION}" "${remote}"
    echo "  done."
}

build_manager() {
    local remote="docker.io/${DOCKER_NS}/uranus-manager:${VERSION}"
    if remote_tag_exists "${remote}"; then
        echo "[manager] ${VERSION} already exists remotely, skipping."
        return 0
    fi
    echo "[manager] Building OpenClaw Manager..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-context shared=./shared/lib \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg BUILTIN_VERSION="${VERSION}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(controller_image_ref)" \
        -f ./manager/Dockerfile \
        -t hiclaw/hiclaw-manager:${VERSION} \
        .
    tag_and_push "hiclaw/hiclaw-manager:${VERSION}" "${remote}"
    echo "  done."
}

build_manager_copaw() {
    local remote="docker.io/${DOCKER_NS}/uranus-manager-copaw:${VERSION}"
    if remote_tag_exists "${remote}"; then
        echo "[manager-copaw] ${VERSION} already exists remotely, skipping."
        return 0
    fi
    echo "[manager-copaw] Building CoPaw Manager..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg BUILTIN_VERSION="${VERSION}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(controller_image_ref)" \
        -f ./manager/Dockerfile.copaw \
        -t hiclaw/hiclaw-manager-copaw:${VERSION} \
        .
    tag_and_push "hiclaw/hiclaw-manager-copaw:${VERSION}" "${remote}"
    echo "  done."
}

build_hermes() {
    local remote="docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION}"
    if remote_tag_exists "${remote}"; then
        echo "[hermes] ${VERSION} already exists remotely, skipping."
        return 0
    fi
    echo "[hermes] Building (includes hermes-web-ui)..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-context shared=./shared/lib \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg NODE_IMAGE="${NODE_IMAGE}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(controller_image_ref)" \
        -t hiclaw/hiclaw-hermes-worker:${VERSION} \
        ./hermes
    tag_and_push "hiclaw/hiclaw-hermes-worker:${VERSION}" "${remote}"
    echo "  done."
}

build_copaw() {
    local remote="docker.io/${DOCKER_NS}/uranus-copaw-worker:${VERSION}"
    if remote_tag_exists "${remote}"; then
        echo "[copaw] ${VERSION} already exists remotely, skipping."
        return 0
    fi
    echo "[copaw] Building..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-context shared=./shared/lib \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(controller_image_ref)" \
        -t hiclaw/hiclaw-copaw-worker:${VERSION} \
        ./copaw
    tag_and_push "hiclaw/hiclaw-copaw-worker:${VERSION}" "${remote}"
    echo "  done."
}

build_openclaw() {
    local remote="docker.io/${DOCKER_NS}/uranus-worker:${VERSION}"
    if remote_tag_exists "${remote}"; then
        echo "[openclaw] ${VERSION} already exists remotely, skipping."
        return 0
    fi
    echo "[openclaw] Building..."
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
        --build-arg HICLAW_CONTROLLER_IMAGE="$(controller_image_ref)" \
        -t hiclaw/hiclaw-worker:${VERSION} \
        ./worker
    tag_and_push "hiclaw/hiclaw-worker:${VERSION}" "${remote}"
    echo "  done."
}

check_all() {
    echo "Checking remote tags for ${VERSION}..."
    for name in controller manager manager-copaw embedded hermes copaw openclaw; do
        case "${name}" in
            controller)    img="uranus-controller" ;;
            manager)       img="uranus-manager" ;;
            manager-copaw) img="uranus-manager-copaw" ;;
            embedded)      img="uranus-embedded" ;;
            hermes)        img="uranus-hermes-worker" ;;
            copaw)         img="uranus-copaw-worker" ;;
            openclaw)      img="uranus-worker" ;;
        esac
        local remote="docker.io/${DOCKER_NS}/${img}:${VERSION}"
        if docker manifest inspect "${remote}" >/dev/null 2>&1; then
            echo "  ${name}: exists"
        else
            echo "  ${name}: NEEDS BUILD"
        fi
    done
}

print_summary() {
    echo ""
    echo "============================================"
    echo "  Deploy config:"
    echo "============================================"
    cat <<EOF
HICLAW_VERSION=${VERSION}
HICLAW_INSTALL_EMBEDDED_IMAGE=docker.io/${DOCKER_NS}/uranus-embedded:${VERSION}
HICLAW_INSTALL_CONTROLLER_IMAGE=docker.io/${DOCKER_NS}/uranus-controller:${VERSION}
HICLAW_INSTALL_MANAGER_IMAGE=docker.io/${DOCKER_NS}/uranus-manager:${VERSION}
HICLAW_INSTALL_MANAGER_COPAW_IMAGE=docker.io/${DOCKER_NS}/uranus-manager-copaw:${VERSION}
HICLAW_MANAGER_RUNTIME=openclaw
HICLAW_DEFAULT_WORKER_RUNTIME=hermes
HICLAW_INSTALL_HERMES_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-hermes-worker:${VERSION}
HICLAW_INSTALL_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-worker:${VERSION}
HICLAW_INSTALL_COPAW_WORKER_IMAGE=docker.io/${DOCKER_NS}/uranus-copaw-worker:${VERSION}
EOF
}

# ── Main ─────────────────────────────────────────────────────────────────

TARGETS=("$@")

if [ "${#TARGETS[@]}" -eq 0 ]; then
    TARGETS=(controller manager manager-copaw embedded hermes copaw openclaw)
fi

if [ "${TARGETS[0]}" = "--check" ]; then
    check_all
    exit 0
fi

echo "============================================"
echo "  Uranus Build & Push"
echo "  Namespace: ${DOCKER_NS}"
echo "  Version:   ${VERSION}"
echo "  Targets:   ${TARGETS[*]}"
echo "  Force:     ${FORCE_BUILD}"
echo "============================================"
echo ""

for target in "${TARGETS[@]}"; do
    case "${target}" in
        controller) build_controller ;;
        manager)    build_manager ;;
        manager-copaw) build_manager_copaw ;;
        embedded)   build_embedded ;;
        hermes)     build_hermes ;;
        copaw)      build_copaw ;;
        openclaw)   build_openclaw ;;
        *)
            echo "Unknown target: ${target}"
            echo "Available: controller, manager, manager-copaw, embedded, hermes, copaw, openclaw"
            exit 1
            ;;
    esac
done

print_summary
