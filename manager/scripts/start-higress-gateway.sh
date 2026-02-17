#!/bin/bash
# start-higress-gateway.sh - Start Higress Gateway (Envoy proxy)
# Listens on port 8080 (HTTP) and 8443 (HTTPS)

source /opt/hiclaw/scripts/base.sh

exec /opt/higress-data/bin/envoy \
    2>&1
