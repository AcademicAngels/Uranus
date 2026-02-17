#!/bin/bash
# start-higress-apiserver.sh - Start Higress API Server
# This delegates to the Higress all-in-one startup sequence.
# The actual binary paths and arguments are from the Higress all-in-one image.

source /opt/hiclaw/scripts/base.sh

mkdir -p /data/higress

# Higress API Server manages the configuration store
exec /opt/higress-data/bin/apiserver \
    --secure-port=8443 \
    --storage-type=nacos \
    --nacos-server=127.0.0.1:8848 \
    --file-root-dir=/data/higress \
    2>&1
