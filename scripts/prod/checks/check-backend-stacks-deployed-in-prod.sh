#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-prod}"
REGION="${REGION:-eu-west-1}"

stacks=(
  "farmmapping-backend-vpc"
  "farmmapping-backend-alb"
  "farmmapping-backend-ecs"
  "farmmapping-backend-rds"
  "farmmapping-backend-app"
  "farmmapping-backend-schedule"
)

fail=0
for name in "${stacks[@]}"; do
  status="$(aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
    --stack-name "$name" \
    --query "Stacks[0].StackStatus" \
    --output text 2>/dev/null || true)"

  if [[ -z "$status" || "$status" == "None" ]]; then
    echo "$name: MISSING"
    fail=1
    continue
  fi

  echo "$name: $status"

  case "$status" in
    CREATE_COMPLETE|UPDATE_COMPLETE)
      ;;
    *)
      fail=1
      ;;
  esac
done

exit "$fail"
