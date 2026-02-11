#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-prod}"
REGION="${REGION:-eu-west-1}"

get_previous_param_keys() {
  local name="$1"
  local keys_text=""
  keys_text="$(aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
    --stack-name "$name" \
    --query "Stacks[0].Parameters[].ParameterKey" \
    --output text 2>/dev/null || true)"
  if [[ -z "$keys_text" || "$keys_text" == "None" ]]; then
    return 0
  fi
  printf '%s' "$keys_text" | tr '\t' ' ' | tr -s ' ' '\n'
}

deploy_stack() {
  local name="$1"
  local template="$2"
  local params_file="${3:-}"
  local capabilities="${4:-}"
  local status=""
  local update_out=""

  status="$(aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
    --stack-name "$name" \
    --query "Stacks[0].StackStatus" \
    --output text 2>/dev/null || true)"

  if [[ -n "$status" && "$status" != "None" ]]; then
    if [[ "$status" == "ROLLBACK_COMPLETE" || "$status" == "ROLLBACK_FAILED" ]]; then
      echo "$name is in $status. Delete the stack before re-deploying."
      return 1
    fi
    if [[ "$status" == *"_IN_PROGRESS" ]]; then
      echo "$name is in progress ($status). Wait for it to complete, then re-run."
      return 1
    fi

    echo "Updating $name..."
    if [[ -n "$params_file" ]]; then
      update_out="$(aws --profile "$PROFILE" --region "$REGION" cloudformation update-stack \
        --stack-name "$name" \
        --template-body "file://${template}" \
        --parameters "file://${params_file}" \
        ${capabilities:+--capabilities "$capabilities"} 2>&1)" || true
    else
      local params=()
      while IFS= read -r key; do
        if [[ -n "$key" ]]; then
          params+=("ParameterKey=${key},UsePreviousValue=true")
        fi
      done < <(get_previous_param_keys "$name")
      local param_args=()
      if [[ ${#params[@]} -gt 0 ]]; then
        param_args+=(--parameters)
        param_args+=("${params[@]}")
      fi
      update_out="$(aws --profile "$PROFILE" --region "$REGION" cloudformation update-stack \
        --stack-name "$name" \
        --template-body "file://${template}" \
        "${param_args[@]}" \
        ${capabilities:+--capabilities "$capabilities"} 2>&1)" || true
    fi
    if echo "$update_out" | grep -q "No updates are to be performed"; then
      echo "$name: no updates."
      return 0
    fi
    if [[ -n "$update_out" ]]; then
      echo "$update_out"
    fi
    echo "Waiting for $name update to complete..."
    aws --profile "$PROFILE" --region "$REGION" cloudformation wait stack-update-complete --stack-name "$name"
  else
    echo "Creating $name..."
    if [[ -n "$params_file" ]]; then
      aws --profile "$PROFILE" --region "$REGION" cloudformation create-stack \
        --stack-name "$name" \
        --template-body "file://${template}" \
        --parameters "file://${params_file}" \
        ${capabilities:+--capabilities "$capabilities"}
    else
      aws --profile "$PROFILE" --region "$REGION" cloudformation create-stack \
        --stack-name "$name" \
        --template-body "file://${template}" \
        ${capabilities:+--capabilities "$capabilities"}
    fi
    echo "Waiting for $name create to complete..."
    aws --profile "$PROFILE" --region "$REGION" cloudformation wait stack-create-complete --stack-name "$name"
  fi
}

deploy_stack "farmmapping-cloudfront-prod" "infra/env/cloudfront-prod.yaml"
deploy_stack "farmmapping-s3-prod" "infra/env/s3-prod.yaml"
deploy_stack "farmmapping-backend-vpc" "infra/env/backend-vpc.yaml" "infra/env/params/backend-vpc.json"
deploy_stack "farmmapping-backend-alb" "infra/env/backend-alb.yaml"
deploy_stack "farmmapping-backend-ecs" "infra/env/backend-ecs.yaml" "" "CAPABILITY_NAMED_IAM"
rds_params="infra/env/params/backend-rds.json"
if [[ -f "infra/env/params/backend-rds.local.json" ]]; then
  rds_params="infra/env/params/backend-rds.local.json"
fi
deploy_stack "farmmapping-backend-rds" "infra/env/backend-rds.yaml" "$rds_params"
deploy_stack "farmmapping-backend-app" "infra/env/backend-app.yaml" "" "CAPABILITY_NAMED_IAM"
deploy_stack "farmmapping-backend-schedule" "infra/env/backend-schedule.yaml" "" "CAPABILITY_NAMED_IAM"
