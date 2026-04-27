#!/bin/bash
# Uranus Build & Push Script
#
# Builds and optionally pushes the Docker images used by Uranus deployments.
# One run resolves exactly one image tag and uses that tag for every image.
#
# Usage:
#   bash scripts/build-and-push.sh                    # build + push all
#   SKIP_PUSH=1 bash scripts/build-and-push.sh        # local build only
#   bash scripts/build-and-push.sh hermes             # build controller + hermes
#   bash scripts/build-and-push.sh --check            # check remote tags
#
# Available targets: controller, manager, manager-copaw, embedded, hermes, copaw, openclaw
#
# Environment variables:
#   DOCKER_NS               DockerHub namespace (default: tingchaopavilion)
#   VERSION                 Image tag. If unset: dev-<short-sha> or dev-<short-sha>-dirty-<timestamp>
#   FORCE_BUILD             Reserved compatibility flag; set to 1 to ignore remote-skip settings
#   SKIP_PUSH               Set to 1 to build only, no push (default: 0)
#   SKIP_EXISTING_REMOTE    Set to 1 to skip targets whose remote tag already exists (default: 0)
#   PLAN_ONLY               Set to 1 to print the resolved plan without building (default: 0)
#   DEPLOY_ENV_FILE         Write resolved deploy env here (default: /tmp/uranus-<tag>.env)
#   INSTALL_WRAPPER_FILE    Write one-command local installer here (default: /tmp/uranus-install-<tag>.sh)
#   HIGRESS_REGISTRY        China mirror for Higress base images
#   DOCKERHUB_MIRROR_PREFIX Mirror prefix for Docker Hub pulls
#   NODE_IMAGE              Node.js 23 image for hermes-web-ui build stage
#   DOCKER_BUILD_ARGS       Extra docker build args (e.g., proxy settings)

set -euo pipefail

DOCKER_NS="${DOCKER_NS:-tingchaopavilion}"
FORCE_BUILD="${FORCE_BUILD:-0}"
SKIP_PUSH="${SKIP_PUSH:-0}"
SKIP_EXISTING_REMOTE="${SKIP_EXISTING_REMOTE:-0}"
PLAN_ONLY="${PLAN_ONLY:-0}"
HIGRESS_REGISTRY="${HIGRESS_REGISTRY:-higress-registry.cn-hangzhou.cr.aliyuncs.com}"
DOCKERHUB_MIRROR_PREFIX="${DOCKERHUB_MIRROR_PREFIX:-m.daocloud.io/docker.io}"
NODE_IMAGE="${NODE_IMAGE:-${DOCKERHUB_MIRROR_PREFIX}/library/node:23-slim}"
DOCKER_BUILD_ARGS="${DOCKER_BUILD_ARGS:-}"
export DOCKER_BUILDKIT=1

ALL_TARGETS=(controller manager manager-copaw embedded hermes copaw openclaw)

resolve_tag() {
    if [ -n "${VERSION:-}" ]; then
        echo "${VERSION}"
        return 0
    fi

    local sha dirty=""
    sha="$(git rev-parse --short HEAD)"
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        dirty="-dirty-$(date -u +%Y%m%d%H%M%S)"
    fi
    echo "dev-${sha}${dirty}"
}

BUILD_TAG="$(resolve_tag)"
VERSION="${BUILD_TAG}"
export VERSION
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-/tmp/uranus-${BUILD_TAG}.env}"
INSTALL_WRAPPER_FILE="${INSTALL_WRAPPER_FILE:-/tmp/uranus-install-${BUILD_TAG}.sh}"

local_image() {
    case "$1" in
        controller)    echo "hiclaw/hiclaw-controller:${BUILD_TAG}" ;;
        manager)       echo "hiclaw/hiclaw-manager:${BUILD_TAG}" ;;
        manager-copaw) echo "hiclaw/hiclaw-manager-copaw:${BUILD_TAG}" ;;
        embedded)      echo "hiclaw/hiclaw-embedded:${BUILD_TAG}" ;;
        hermes)        echo "hiclaw/hiclaw-hermes-worker:${BUILD_TAG}" ;;
        copaw)         echo "hiclaw/hiclaw-copaw-worker:${BUILD_TAG}" ;;
        openclaw)      echo "hiclaw/hiclaw-worker:${BUILD_TAG}" ;;
        openclaw-base) echo "hiclaw/openclaw-base:${BUILD_TAG}" ;;
        *) echo "unknown target: $1" >&2; return 1 ;;
    esac
}

remote_image() {
    case "$1" in
        controller)    echo "docker.io/${DOCKER_NS}/uranus-controller:${BUILD_TAG}" ;;
        manager)       echo "docker.io/${DOCKER_NS}/uranus-manager:${BUILD_TAG}" ;;
        manager-copaw) echo "docker.io/${DOCKER_NS}/uranus-manager-copaw:${BUILD_TAG}" ;;
        embedded)      echo "docker.io/${DOCKER_NS}/uranus-embedded:${BUILD_TAG}" ;;
        hermes)        echo "docker.io/${DOCKER_NS}/uranus-hermes-worker:${BUILD_TAG}" ;;
        copaw)         echo "docker.io/${DOCKER_NS}/uranus-copaw-worker:${BUILD_TAG}" ;;
        openclaw)      echo "docker.io/${DOCKER_NS}/uranus-worker:${BUILD_TAG}" ;;
        *) echo "unknown target: $1" >&2; return 1 ;;
    esac
}

remote_tag_exists() {
    docker manifest inspect "$(remote_image "$1")" >/dev/null 2>&1
}

should_skip_remote() {
    local target="$1"
    [ "${FORCE_BUILD}" = "1" ] && return 1
    [ "${SKIP_PUSH}" = "1" ] && return 1
    [ "${SKIP_EXISTING_REMOTE}" = "1" ] || return 1
    remote_tag_exists "${target}"
}

tag_and_push() {
    local target="$1"
    local local_tag remote_tag
    local_tag="$(local_image "${target}")"
    remote_tag="$(remote_image "${target}")"

    if [ "${SKIP_PUSH}" = "1" ]; then
        echo "  (skip push: SKIP_PUSH=1)"
        return 0
    fi

    docker tag "${local_tag}" "${remote_tag}"
    docker push "${remote_tag}"
}

cleanup_controller_agent() {
    rm -rf ./hiclaw-controller/agent
}

build_controller() {
    if should_skip_remote controller; then
        echo "[controller] ${BUILD_TAG} already exists remotely, skipping."
        if ! docker image inspect "$(local_image controller)" >/dev/null 2>&1; then
            docker pull "$(remote_image controller)"
            docker tag "$(remote_image controller)" "$(local_image controller)"
        fi
        return 0
    fi

    echo "[controller] Building $(local_image controller)..."
    cleanup_controller_agent
    cp -r ./manager/agent ./hiclaw-controller/agent
    trap cleanup_controller_agent RETURN
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        -t "$(local_image controller)" \
        ./hiclaw-controller
    cleanup_controller_agent
    trap - RETURN
    tag_and_push controller
    echo "  done."
}

require_controller_image() {
    if ! docker image inspect "$(local_image controller)" >/dev/null 2>&1; then
        echo "ERROR: missing local controller image $(local_image controller)" >&2
        echo "Build the controller first or run this script with the dependent target." >&2
        exit 1
    fi
}

build_embedded() {
    if should_skip_remote embedded; then
        echo "[embedded] ${BUILD_TAG} already exists remotely, skipping."
        return 0
    fi
    require_controller_image
    echo "[embedded] Building $(local_image embedded)..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(local_image controller)" \
        -f ./hiclaw-controller/Dockerfile.embedded \
        -t "$(local_image embedded)" \
        .
    tag_and_push embedded
    echo "  done."
}

build_manager() {
    if should_skip_remote manager; then
        echo "[manager] ${BUILD_TAG} already exists remotely, skipping."
        return 0
    fi
    require_controller_image
    echo "[manager] Building $(local_image manager)..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-context shared=./shared/lib \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg BUILTIN_VERSION="${BUILD_TAG}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(local_image controller)" \
        -f ./manager/Dockerfile \
        -t "$(local_image manager)" \
        .
    tag_and_push manager
    echo "  done."
}

build_manager_copaw() {
    if should_skip_remote manager-copaw; then
        echo "[manager-copaw] ${BUILD_TAG} already exists remotely, skipping."
        return 0
    fi
    require_controller_image
    echo "[manager-copaw] Building $(local_image manager-copaw)..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg BUILTIN_VERSION="${BUILD_TAG}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(local_image controller)" \
        -f ./manager/Dockerfile.copaw \
        -t "$(local_image manager-copaw)" \
        .
    tag_and_push manager-copaw
    echo "  done."
}

build_hermes() {
    if should_skip_remote hermes; then
        echo "[hermes] ${BUILD_TAG} already exists remotely, skipping."
        return 0
    fi
    require_controller_image
    echo "[hermes] Building $(local_image hermes) (includes hermes-web-ui)..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-context shared=./shared/lib \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg NODE_IMAGE="${NODE_IMAGE}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(local_image controller)" \
        -t "$(local_image hermes)" \
        ./hermes
    tag_and_push hermes
    echo "  done."
}

build_copaw() {
    if should_skip_remote copaw; then
        echo "[copaw] ${BUILD_TAG} already exists remotely, skipping."
        return 0
    fi
    require_controller_image
    echo "[copaw] Building $(local_image copaw)..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-context shared=./shared/lib \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(local_image controller)" \
        -t "$(local_image copaw)" \
        ./copaw
    tag_and_push copaw
    echo "  done."
}

build_openclaw() {
    if should_skip_remote openclaw; then
        echo "[openclaw] ${BUILD_TAG} already exists remotely, skipping."
        return 0
    fi
    require_controller_image
    echo "[openclaw] Building $(local_image openclaw-base)..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        -t "$(local_image openclaw-base)" \
        ./openclaw-base
    echo "[openclaw] Building $(local_image openclaw)..."
    docker build \
        ${DOCKER_BUILD_ARGS} \
        --build-context shared=./shared/lib \
        --build-arg HIGRESS_REGISTRY="${HIGRESS_REGISTRY}" \
        --build-arg OPENCLAW_BASE_IMAGE="$(local_image openclaw-base)" \
        --build-arg HICLAW_CONTROLLER_IMAGE="$(local_image controller)" \
        -t "$(local_image openclaw)" \
        ./worker
    tag_and_push openclaw
    echo "  done."
}

check_all() {
    echo "Checking remote tags for ${BUILD_TAG}..."
    for target in "${ALL_TARGETS[@]}"; do
        if remote_tag_exists "${target}"; then
            echo "  ${target}: exists ($(remote_image "${target}"))"
        else
            echo "  ${target}: NEEDS BUILD ($(remote_image "${target}"))"
        fi
    done
}

deploy_config_content() {
    local ref_fn="$1"
    cat <<EOF
export HICLAW_VERSION=${BUILD_TAG}
export HICLAW_INSTALL_EMBEDDED_IMAGE=$(${ref_fn} embedded)
export HICLAW_INSTALL_CONTROLLER_IMAGE=$(${ref_fn} controller)
export HICLAW_INSTALL_MANAGER_IMAGE=$(${ref_fn} manager)
export HICLAW_INSTALL_MANAGER_COPAW_IMAGE=$(${ref_fn} manager-copaw)
export HICLAW_MANAGER_RUNTIME=openclaw
export HICLAW_DEFAULT_WORKER_RUNTIME=hermes
export HICLAW_INSTALL_HERMES_WORKER_IMAGE=$(${ref_fn} hermes)
export HICLAW_INSTALL_WORKER_IMAGE=$(${ref_fn} openclaw)
export HICLAW_INSTALL_COPAW_WORKER_IMAGE=$(${ref_fn} copaw)
export HICLAW_VAULT_PATH=shared/vault
EOF
}

write_deploy_files() {
    local ref_fn="$1"
    local repo_dir
    repo_dir="$(pwd)"

    umask 077
    deploy_config_content "${ref_fn}" > "${DEPLOY_ENV_FILE}"
    cat > "${INSTALL_WRAPPER_FILE}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "${DEPLOY_ENV_FILE}"
exec bash "${repo_dir}/install/uranus-install.sh" "\$@"
EOF
    chmod +x "${INSTALL_WRAPPER_FILE}"
}

print_summary() {
    local ref_fn="remote_image"
    local title="Remote deploy config"
    if [ "${SKIP_PUSH}" = "1" ]; then
        ref_fn="local_image"
        title="Local deploy config"
    fi

    write_deploy_files "${ref_fn}"

    echo ""
    echo "============================================"
    echo "  ${title}:"
    echo "============================================"
    deploy_config_content "${ref_fn}"
    echo ""
    echo "Wrote env file: ${DEPLOY_ENV_FILE}"
    echo "Run installer:  bash ${INSTALL_WRAPPER_FILE}"
}

normalize_targets() {
    local input=("$@")
    local output=()
    local need_controller=0
    local seen_controller=0

    if [ "${#input[@]}" -eq 0 ]; then
        input=("${ALL_TARGETS[@]}")
    fi

    for target in "${input[@]}"; do
        case "${target}" in
            controller) seen_controller=1 ;;
            manager|manager-copaw|embedded|hermes|copaw|openclaw) need_controller=1 ;;
            *)
                echo "Unknown target: ${target}" >&2
                echo "Available: ${ALL_TARGETS[*]}" >&2
                exit 1
                ;;
        esac
    done

    if [ "${need_controller}" = "1" ] && [ "${seen_controller}" = "0" ]; then
        output+=(controller)
    fi

    for target in "${input[@]}"; do
        local already=0
        for existing in "${output[@]}"; do
            if [ "${existing}" = "${target}" ]; then
                already=1
                break
            fi
        done
        [ "${already}" = "0" ] && output+=("${target}")
    done

    printf '%s\n' "${output[@]}"
}

run_target() {
    case "$1" in
        controller)    build_controller ;;
        manager)       build_manager ;;
        manager-copaw) build_manager_copaw ;;
        embedded)      build_embedded ;;
        hermes)        build_hermes ;;
        copaw)         build_copaw ;;
        openclaw)      build_openclaw ;;
    esac
}

# ── Main ─────────────────────────────────────────────────────────────────

if [ "${1:-}" = "--check" ]; then
    check_all
    exit 0
fi

NORMALIZED_TARGETS="$(normalize_targets "$@")"
mapfile -t TARGETS <<< "${NORMALIZED_TARGETS}"

echo "============================================"
echo "  Uranus Build & Push"
echo "  Namespace:             ${DOCKER_NS}"
echo "  Build tag:             ${BUILD_TAG}"
echo "  Targets:               ${TARGETS[*]}"
echo "  Skip push:             ${SKIP_PUSH}"
echo "  Skip existing remote:  ${SKIP_EXISTING_REMOTE}"
echo "  Force build:           ${FORCE_BUILD}"
echo "  Plan only:             ${PLAN_ONLY}"
echo "============================================"
echo ""

if [ "${PLAN_ONLY}" = "1" ]; then
    print_summary
    exit 0
fi

for target in "${TARGETS[@]}"; do
    run_target "${target}"
done

print_summary
