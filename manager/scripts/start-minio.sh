#!/bin/bash
# start-minio.sh - Start MinIO object storage (single node, single disk)

export MINIO_ROOT_USER="${HICLAW_MINIO_USER:-minioadmin}"
export MINIO_ROOT_PASSWORD="${HICLAW_MINIO_PASSWORD:-minioadmin}"

mkdir -p /data/minio

exec minio server /data/minio --console-address ":9001" --address ":9000"
