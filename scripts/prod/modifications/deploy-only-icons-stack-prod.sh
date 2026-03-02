#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-prod}"
REGION="${AWS_REGION:-eu-west-1}"
STACK_NAME="${STACK_NAME:-farmmapping-icons-prod}"
TEMPLATE_FILE="${TEMPLATE_FILE:-infra/env/icons-prod.yaml}"

status="$(aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null || true)"

if [[ -n "$status" && "$status" != "None" ]]; then
  echo "Updating $STACK_NAME..."
  set +e
  out="$(aws --profile "$PROFILE" --region "$REGION" cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" 2>&1)"
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    if echo "$out" | grep -q "No updates are to be performed"; then
      echo "$STACK_NAME: no updates."
      exit 0
    fi
    echo "$out"
    exit $rc
  fi

  echo "Waiting for $STACK_NAME update to complete..."
  aws --profile "$PROFILE" --region "$REGION" cloudformation wait stack-update-complete --stack-name "$STACK_NAME"
  echo "$STACK_NAME updated."
else
  echo "Creating $STACK_NAME..."
  aws --profile "$PROFILE" --region "$REGION" cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE"

  echo "Waiting for $STACK_NAME create to complete..."
  aws --profile "$PROFILE" --region "$REGION" cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
  echo "$STACK_NAME created."
fi
