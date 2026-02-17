#!/bin/bash
# start-higress-console.sh - Start Higress Console (Management UI + API)
# Listens on port 8001

source /opt/hiclaw/scripts/base.sh

exec /opt/higress-data/bin/console \
    2>&1
