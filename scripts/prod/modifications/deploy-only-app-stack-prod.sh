#!/usr/bin/env bash
set -euo pipefail

PROFILE=${AWS_PROFILE:-prod}
REGION=${AWS_REGION:-eu-west-1}
STACK_NAME=farmmapping-backend-app
TEMPLATE_FILE=infra/env/backend-app.yaml

aws --profile "$PROFILE" --region "$REGION" cloudformation update-stack \
  --stack-name "$STACK_NAME" \
  --template-body "file://$TEMPLATE_FILE" \
  --capabilities CAPABILITY_NAMED_IAM