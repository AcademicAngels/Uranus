#!/bin/bash
# start-higress-controller.sh - Start Higress Controller

source /opt/hiclaw/scripts/base.sh
waitForService "Higress API Server" "127.0.0.1" 8443 120

exec /opt/higress-data/bin/controller \
    2>&1
