#!/bin/bash
# minio-client.sh - MinIO verification helpers for integration tests

_MINIO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MINIO_LIB_DIR}/test-helpers.sh" 2>/dev/null || true

# Configure mc alias for test MinIO
# Usage: minio_setup
minio_setup() {
    mc alias set hiclaw-test "${TEST_MINIO_URL}" \
        "${TEST_MINIO_USER}" "${TEST_MINIO_PASSWORD}" 2>/dev/null
}

# ============================================================
# File verification
# ============================================================

# Check if a file exists in MinIO
# Usage: minio_file_exists <path>
# Example: minio_file_exists "agents/manager/SOUL.md"
minio_file_exists() {
    local path="$1"
    mc stat "hiclaw-test/hiclaw-storage/${path}" > /dev/null 2>&1
}

# Read file content from MinIO
# Usage: minio_read_file <path>
minio_read_file() {
    local path="$1"
    mc cat "hiclaw-test/hiclaw-storage/${path}" 2>/dev/null
}

# List directory contents in MinIO
# Usage: minio_list_dir <path>
minio_list_dir() {
    local path="$1"
    mc ls "hiclaw-test/hiclaw-storage/${path}" 2>/dev/null
}

# Wait for a file to appear in MinIO
# Usage: minio_wait_for_file <path> [timeout_seconds]
minio_wait_for_file() {
    local path="$1"
    local timeout="${2:-120}"
    local elapsed=0

    while ! minio_file_exists "${path}"; do
        sleep 5
        elapsed=$((elapsed + 5))
        if [ "${elapsed}" -ge "${timeout}" ]; then
            return 1
        fi
    done
    return 0
}
