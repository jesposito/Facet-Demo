#!/bin/sh
set -e

echo "Applying Facet-Demo frontend transformations..."

WORKDIR="${1:-.}"
cd "$WORKDIR"

echo "Working in: $(pwd)"
echo "Frontend transforms complete (overlay files handle the changes)"
