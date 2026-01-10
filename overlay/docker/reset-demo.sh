#!/bin/bash
set -e

echo "$(date): Starting demo data reset..."

DATA_DIR="${DATA_DIR:-/data}"
UPLOAD_DIR="${UPLOAD_DIR:-/uploads}"

if [ -d "/app/seed-data" ]; then
    echo "$(date): Restoring from seed data..."
    rm -rf "${DATA_DIR:?}"/* 2>/dev/null || true
    rm -rf "${UPLOAD_DIR:?}"/* 2>/dev/null || true
    cp -r /app/seed-data/data/* "$DATA_DIR/" 2>/dev/null || true
    cp -r /app/seed-data/uploads/* "$UPLOAD_DIR/" 2>/dev/null || true
    echo "$(date): Seed data restored. Restart container to apply."
else
    echo "$(date): No seed data found, clearing data..."
    rm -rf "${DATA_DIR:?}"/* 2>/dev/null || true
    rm -rf "${UPLOAD_DIR:?}"/* 2>/dev/null || true
    echo "$(date): Data cleared. Container will reinitialize on restart."
fi
