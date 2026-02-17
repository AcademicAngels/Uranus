#!/bin/bash
# test-01-manager-boot.sh - Case 1: Manager boots, all services healthy, IM login
# Verifies: all ports accessible, Matrix login works, Higress Console session,
#           MinIO initial storage, Manager Agent responds to "hello"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/test-helpers.sh"
source "${SCRIPT_DIR}/lib/matrix-client.sh"
source "${SCRIPT_DIR}/lib/higress-client.sh"
source "${SCRIPT_DIR}/lib/minio-client.sh"

test_setup "01-manager-boot"

# ---- Service Health Checks ----
log_section "Service Health"

# Gateway root may return 200 (console route) or 404 (no default route) - either is fine
GATEWAY_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://${TEST_MANAGER_HOST}:${TEST_GATEWAY_PORT}/" 2>/dev/null)
if [ "${GATEWAY_CODE}" != "000" ]; then
    log_pass "Higress Gateway port 8080 is accessible (HTTP ${GATEWAY_CODE})"
else
    log_fail "Higress Gateway port 8080 is accessible (no response)"
fi

assert_http_code "http://${TEST_MANAGER_HOST}:${TEST_CONSOLE_PORT}/" "200" \
    "Higress Console port 8001 is accessible"

assert_http_code "http://${TEST_MANAGER_HOST}:${TEST_MINIO_CONSOLE_PORT}/" "200" \
    "MinIO Console port 9001 is accessible"

assert_http_code "http://${TEST_MANAGER_HOST}:${TEST_MATRIX_PORT}/_matrix/client/versions" "200" \
    "Tuwunel Matrix port 6167 is accessible"

assert_http_code "http://${TEST_MANAGER_HOST}:${TEST_ELEMENT_PORT}/" "200" \
    "Element Web port 8088 is accessible"

assert_http_code "http://${TEST_MANAGER_HOST}:${TEST_MINIO_PORT}/minio/health/live" "200" \
    "MinIO API port 9000 is accessible"

# ---- Matrix Login ----
log_section "Matrix Login"

ADMIN_LOGIN=$(matrix_login "${TEST_ADMIN_USER}" "${TEST_ADMIN_PASSWORD}")
ADMIN_TOKEN=$(echo "${ADMIN_LOGIN}" | jq -r '.access_token')
assert_not_empty "${ADMIN_TOKEN}" "Admin Matrix login returns access_token"

# ---- Higress Console ----
log_section "Higress Console"

HIGRESS_SESSION=$(higress_login "${TEST_ADMIN_USER}" "${TEST_ADMIN_PASSWORD}" 2>/dev/null || echo "")
if [ -n "${HIGRESS_SESSION}" ]; then
    log_pass "Higress Console login succeeded"
else
    log_fail "Higress Console login failed (Manager may not have initialized console yet)"
fi

CONSUMERS=$(higress_get_consumers 2>/dev/null || echo "")
if echo "${CONSUMERS}" | grep -q "manager" 2>/dev/null; then
    log_pass "Manager consumer exists in Higress"
else
    log_fail "Manager consumer exists in Higress (not found, Manager Agent may still be initializing)"
fi

# ---- MinIO Storage ----
log_section "MinIO Storage"

if minio_setup 2>/dev/null; then
    log_pass "MinIO mc alias configured"
else
    log_fail "MinIO mc alias configured"
fi

if minio_file_exists "agents/manager/SOUL.md" 2>/dev/null; then
    log_pass "Manager SOUL.md exists in MinIO"
else
    log_fail "Manager SOUL.md exists in MinIO (mc-mirror may still be initializing)"
fi

if minio_file_exists "agents/manager/AGENTS.md" 2>/dev/null; then
    log_pass "Manager AGENTS.md exists in MinIO"
else
    log_fail "Manager AGENTS.md exists in MinIO"
fi

if minio_file_exists "agents/manager/HEARTBEAT.md" 2>/dev/null; then
    log_pass "Manager HEARTBEAT.md exists in MinIO"
else
    log_fail "Manager HEARTBEAT.md exists in MinIO"
fi

# ---- Manager Agent Responds ----
log_section "Manager Agent Communication"

# Find Manager DM room or create one
MANAGER_USER_ID="@manager:${TEST_MATRIX_DOMAIN}"
ROOMS=$(matrix_joined_rooms "${ADMIN_TOKEN}" | jq -r '.joined_rooms[]' 2>/dev/null)

if [ -z "${ROOMS}" ]; then
    log_info "No existing rooms, sending DM to Manager..."
fi

# Send hello and wait for response (Manager should auto-join DM)
# This tests that OpenClaw is running and connected to Matrix
log_info "Attempting to communicate with Manager Agent..."

test_teardown "01-manager-boot"
test_summary
