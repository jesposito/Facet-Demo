#!/bin/bash
set -e

CONTAINER_NAME="${CONTAINER_NAME:-facet-demo}"
DATA_DIR="${DATA_DIR:-/mnt/user/appdata/facet-demo}"
UPLOADS_DIR="${UPLOADS_DIR:-/mnt/user/appdata/facet-demo/uploads}"

echo "$(date): Starting daily reset of Facet-Demo..."

docker stop "$CONTAINER_NAME" 2>/dev/null || true

echo "Clearing data directories..."
rm -rf "${DATA_DIR:?}"/* 2>/dev/null || true
rm -rf "${UPLOADS_DIR:?}"/* 2>/dev/null || true

docker start "$CONTAINER_NAME"

echo "Waiting for container to initialize..."
sleep 10

echo "$(date): Facet-Demo reset complete!"
