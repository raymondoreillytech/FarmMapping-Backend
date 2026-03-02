#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-prod}"
REGION="${AWS_REGION:-eu-west-1}"
STACK_NAME="${STACK_NAME:-farmmapping-icons-prod}"
CLOUDFRONT_STACK="${CLOUDFRONT_STACK:-farmmapping-cloudfront-prod}"
BUCKET="${BUCKET:-}"
ICONS_DIR="${ICONS_DIR:-static/icons}"
S3_PREFIX="${S3_PREFIX:-icons}"
INVALIDATE_CLOUDFRONT="${INVALIDATE_CLOUDFRONT:-true}"

resolve_bucket() {
  aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='IconsBucketName'].OutputValue" \
    --output text 2>/dev/null || true
}

resolve_distribution_id() {
  aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
    --stack-name "$CLOUDFRONT_STACK" \
    --query "Stacks[0].Outputs[?OutputKey=='SiteDistributionId'].OutputValue" \
    --output text 2>/dev/null || true
}

if [[ -z "$BUCKET" ]]; then
  BUCKET="$(resolve_bucket)"
fi

if [[ -z "$BUCKET" || "$BUCKET" == "None" ]]; then
  echo "Could not resolve bucket from stack: $STACK_NAME"
  echo "Set BUCKET manually or deploy the icons stack first."
  exit 1
fi

if [[ ! -d "$ICONS_DIR" ]]; then
  echo "ICONS_DIR not found: $ICONS_DIR"
  exit 1
fi

shopt -s nullglob
icon_files=(
  "$ICONS_DIR"/*.png
  "$ICONS_DIR"/*.svg
  "$ICONS_DIR"/*.jpg
  "$ICONS_DIR"/*.jpeg
)
shopt -u nullglob

if [[ ${#icon_files[@]} -eq 0 ]]; then
  echo "No icon files found in $ICONS_DIR (expected png/svg/jpg/jpeg)."
  exit 1
fi

echo "Uploading icons..."
echo "  profile:  $PROFILE"
echo "  region:   $REGION"
echo "  bucket:   $BUCKET"
echo "  icon dir: $ICONS_DIR"
echo "  s3 path:  s3://$BUCKET/$S3_PREFIX/"

aws --profile "$PROFILE" --region "$REGION" s3 sync \
  "$ICONS_DIR" "s3://$BUCKET/$S3_PREFIX/" \
  --delete \
  --exclude "*" \
  --include "*.png" \
  --include "*.svg" \
  --include "*.jpg" \
  --include "*.jpeg" \
  --cache-control "public,max-age=31536000,immutable" \
  --only-show-errors

echo "Icon upload complete."

if [[ "$INVALIDATE_CLOUDFRONT" == "true" ]]; then
  dist_id="$(resolve_distribution_id)"
  if [[ -n "$dist_id" && "$dist_id" != "None" ]]; then
    invalidation_id="$(aws --profile "$PROFILE" --region "$REGION" cloudfront create-invalidation \
      --distribution-id "$dist_id" \
      --paths "/icons/*" \
      --query "Invalidation.Id" \
      --output text)"
    echo "CloudFront invalidation created: $invalidation_id"
  else
    echo "Skipping invalidation: could not resolve distribution id from $CLOUDFRONT_STACK."
  fi
fi
