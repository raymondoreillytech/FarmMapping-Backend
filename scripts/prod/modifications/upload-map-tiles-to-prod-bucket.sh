#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-prod}"
REGION="${AWS_REGION:-eu-west-1}"
BUCKET="${BUCKET:-farmmapping-map-tiles-prod}"

# Set TILE_ROOT to the folder that contains v*/ (e.g., static/basemaps/tiles)
TILE_ROOT="${TILE_ROOT:-static/basemaps/tiles}"
VERSION_ARG="${1:-}"

usage() {
  cat <<'EOF'
Usage:
  scripts/prod/modifications/upload-map-tiles-to-prod-bucket.sh [vN]

Examples:
  # Upload all versions under static/basemaps/tiles to s3://<bucket>/tiles/
  scripts/prod/modifications/upload-map-tiles-to-prod-bucket.sh

  # Upload only v0 from static/basemaps/tiles/v0 to s3://<bucket>/tiles/v0/
  scripts/prod/modifications/upload-map-tiles-to-prod-bucket.sh v0
EOF
}

if [[ "$VERSION_ARG" == "-h" || "$VERSION_ARG" == "--help" ]]; then
  usage
  exit 0
fi

if [ ! -d "$TILE_ROOT" ]; then
  echo "TILE_ROOT not found: $TILE_ROOT"
  exit 1
fi

if [[ -n "$VERSION_ARG" && ! "$VERSION_ARG" =~ ^v[0-9]+$ ]]; then
  echo "Invalid version '$VERSION_ARG'. Expected format like v0, v1, v2."
  exit 1
fi

SRC_DIR="$TILE_ROOT"
DEST_URI="s3://$BUCKET/tiles"
UPLOAD_SCOPE="all versions"

if [[ -n "$VERSION_ARG" ]]; then
  SRC_DIR="$TILE_ROOT/$VERSION_ARG"
  DEST_URI="s3://$BUCKET/tiles/$VERSION_ARG"
  UPLOAD_SCOPE="version $VERSION_ARG only"
  if [[ ! -d "$SRC_DIR" ]]; then
    echo "Version folder not found: $SRC_DIR"
    exit 1
  fi
fi

echo "Uploading tiles..."
echo "  profile:  $PROFILE"
echo "  region:   $REGION"
echo "  bucket:   $BUCKET"
echo "  source:   $SRC_DIR"
echo "  dest:     $DEST_URI"
echo "  scope:    $UPLOAD_SCOPE"

# Sync preserves directory structure.
aws --profile "$PROFILE" --region "$REGION" s3 sync \
  "$SRC_DIR" "$DEST_URI" \
  --exclude "*" \
  --include "*.png" \
  --include "*.jpg" \
  --include "*.jpeg" \
  --only-show-errors

echo "Done."
