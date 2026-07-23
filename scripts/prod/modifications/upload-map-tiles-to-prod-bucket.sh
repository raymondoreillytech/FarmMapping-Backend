#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-prod}"
REGION="${AWS_REGION:-eu-west-1}"
STACK_NAME="${STACK_NAME:-farmmapping-s3-prod}"
BUCKET="${BUCKET:-}"
S3_PREFIX="${S3_PREFIX:-tiles}"

# Set TILE_ROOT to the folder that contains v*/ (e.g., static/basemaps/tiles)
TILE_ROOT="${TILE_ROOT:-static/basemaps/tiles}"
VERSION_ARG="${1:-}"

if [[ -n "${AWS_CLI:-}" ]]; then
  AWS_CMD=("$AWS_CLI")
elif command -v aws >/dev/null 2>&1; then
  AWS_CMD=(aws)
elif command -v py >/dev/null 2>&1; then
  AWS_CMD=(py -m awscli)
elif command -v aws.cmd >/dev/null 2>&1; then
  AWS_CMD=(aws.cmd)
else
  echo "aws CLI not found in PATH."
  exit 2
fi

usage() {
  cat <<'EOF'
Usage:
  scripts/prod/modifications/upload-map-tiles-to-prod-bucket.sh [vN]

Examples:
  # Upload all versions under static/basemaps/tiles to s3://<bucket>/tiles/
  scripts/prod/modifications/upload-map-tiles-to-prod-bucket.sh

  # Upload only v8 from static/basemaps/tiles/v8 to s3://<bucket>/tiles/v8/
  scripts/prod/modifications/upload-map-tiles-to-prod-bucket.sh v8
EOF
}

resolve_bucket() {
  "${AWS_CMD[@]}" --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='MapTilesBucketName'].OutputValue" \
    --output text 2>/dev/null || true
}

ensure_image_tiles() {
  local dir="$1"
  if ! find "$dir" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print -quit | grep -q .; then
    echo "No tile image files found in: $dir"
    exit 1
  fi
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

if [[ -z "$BUCKET" ]]; then
  BUCKET="$(resolve_bucket)"
fi

if [[ -z "$BUCKET" || "$BUCKET" == "None" ]]; then
  echo "Could not resolve map tiles bucket from stack: $STACK_NAME"
  echo "Set BUCKET manually or deploy the S3 stack first."
  exit 1
fi

SRC_DIR="$TILE_ROOT"
DEST_URI="s3://$BUCKET"
UPLOAD_SCOPE="all versions"
SYNC_ARGS=(
  --exclude "*"
  --include "*.png"
  --include "*.jpg"
  --include "*.jpeg"
  --only-show-errors
)

if [[ -n "$S3_PREFIX" ]]; then
  DEST_URI="$DEST_URI/$S3_PREFIX"
fi

if [[ -n "$VERSION_ARG" ]]; then
  SRC_DIR="$TILE_ROOT/$VERSION_ARG"
  DEST_URI="$DEST_URI/$VERSION_ARG"
  UPLOAD_SCOPE="version $VERSION_ARG only"
  if [[ ! -d "$SRC_DIR" ]]; then
    echo "Version folder not found: $SRC_DIR"
    exit 1
  fi
  SYNC_ARGS+=(--delete)
fi

ensure_image_tiles "$SRC_DIR"

echo "Uploading tiles..."
echo "  profile:  $PROFILE"
echo "  region:   $REGION"
echo "  stack:    $STACK_NAME"
echo "  bucket:   $BUCKET"
echo "  prefix:   ${S3_PREFIX:-<bucket root>}"
echo "  source:   $SRC_DIR"
echo "  dest:     $DEST_URI"
echo "  scope:    $UPLOAD_SCOPE"
if [[ -n "$VERSION_ARG" ]]; then
  echo "  delete:   true"
fi

# Sync preserves directory structure.
"${AWS_CMD[@]}" --profile "$PROFILE" --region "$REGION" s3 sync \
  "$SRC_DIR" "$DEST_URI" \
  "${SYNC_ARGS[@]}"

echo "Done."
