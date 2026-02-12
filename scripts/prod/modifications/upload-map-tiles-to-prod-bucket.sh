#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-prod}"
REGION="${AWS_REGION:-eu-west-1}"
BUCKET="${BUCKET:-farmmapping-map-tiles-prod}"

# Set TILE_DIR to the folder that contains tiles/v*/ (e.g., static/basemaps)
TILE_DIR="${TILE_DIR:-static/basemaps}"

if [ ! -d "$TILE_DIR" ]; then
  echo "TILE_DIR not found: $TILE_DIR"
  exit 1
fi

echo "Uploading tiles..."
echo "  profile:  $PROFILE"
echo "  region:   $REGION"
echo "  bucket:   $BUCKET"
echo "  tile dir: $TILE_DIR"

# Sync preserves directory structure. This ensures tiles/v*/z/x/y.png stays under tiles/ in S3.
aws --profile "$PROFILE" --region "$REGION" s3 sync \
  "$TILE_DIR" "s3://$BUCKET" \
  --exclude "*" \
  --include "*.jpg" \
  --only-show-errors

echo "Done."
