#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-localstack}"
REGION="${AWS_REGION:-eu-west-1}"
ENDPOINT_URL="${ENDPOINT_URL:-http://localhost:4566}"
BUCKET="${BUCKET:-farmmapping-map-tiles-local}"

# Where your tiles live on disk:
# Set TILE_DIR to the folder that contains v*/ (e.g., static/basemaps/tiles).
TILE_DIR="${TILE_DIR:-static/basemaps/tiles}"

if [ ! -d "$TILE_DIR" ]; then
  echo "TILE_DIR not found: $TILE_DIR"
  exit 1
fi

echo "Uploading tiles (localstack)..."
echo "  profile:  $PROFILE"
echo "  region:   $REGION"
echo "  endpoint: $ENDPOINT_URL"
echo "  bucket:   $BUCKET"
echo "  tile dir: $TILE_DIR"

# Sync preserves directory structure. This ensures v*/z/x/y.png becomes v*/z/x/y.png in S3.
aws --profile "$PROFILE" --region "$REGION" --endpoint-url="$ENDPOINT_URL" s3 sync \
  "$TILE_DIR" "s3://$BUCKET" \
  --exclude "*" \
  --include "*.jpg" \
  --only-show-errors

echo "Done."
