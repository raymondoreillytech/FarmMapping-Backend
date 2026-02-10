#!/usr/bin/env bash
set -euo pipefail

ENDPOINT_URL="${ENDPOINT_URL:-http://localhost:4566}"
BUCKET="${BUCKET:-farmmapping-map-tiles-local}"

# Where your tiles live on disk:
# Set TILE_DIR to the folder that contains z/ (e.g., static/v1 or static/tiles or static)
TILE_DIR="${TILE_DIR:-static/basemaps/tiles}"

if [ ! -d "$TILE_DIR" ]; then
  echo "TILE_DIR not found: $TILE_DIR"
  exit 1
fi

echo "Uploading tiles..."
echo "  endpoint: $ENDPOINT_URL"
echo "  bucket:   $BUCKET"
echo "  tile dir: $TILE_DIR"

# Sync preserves directory structure. This ensures z/x/y.png becomes PREFIX/z/x/y.png
aws --endpoint-url="$ENDPOINT_URL" s3 sync \
  "$TILE_DIR" "s3://$BUCKET" \
  --exclude "*" \
  --include "*.png" \
  --only-show-errors

echo "Done."
