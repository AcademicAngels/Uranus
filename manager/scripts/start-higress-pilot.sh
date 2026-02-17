#!/bin/bash
# start-higress-pilot.sh - Start Higress Pilot (Envoy control plane)

source /opt/hiclaw/scripts/base.sh

exec /opt/higress-data/bin/pilot-discovery discovery \
    2>&1
