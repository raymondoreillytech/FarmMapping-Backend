#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-prod}"
REGION="${AWS_REGION:-eu-west-1}"
STACK_NAME="${STACK_NAME:-farmmapping-cloudfront-prod}"
TEMPLATE_FILE="${TEMPLATE_FILE:-infra/env/cloudfront-prod.yaml}"
PARAMS_FILE="${PARAMS_FILE:-infra/env/params/cloudfront-prod.json}"

if [[ -f "$PARAMS_FILE" ]]; then
  aws --profile "$PROFILE" --region "$REGION" cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --parameters "file://$PARAMS_FILE"
else
  aws --profile "$PROFILE" --region "$REGION" cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE"
fi
