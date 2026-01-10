#!/bin/bash
set -e

echo "$(date): Starting demo data reset..."

DATA_DIR="${DATA_DIR:-/data}"
UPLOAD_DIR="${UPLOAD_DIR:-/uploads}"

rm -rf "${DATA_DIR:?}"/* 2>/dev/null || true
rm -rf "${UPLOAD_DIR:?}"/* 2>/dev/null || true

echo "$(date): Demo data cleared. Container will reinitialize on next request."
