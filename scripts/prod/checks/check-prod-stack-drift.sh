#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-prod}"
REGION="${AWS_REGION:-eu-west-1}"

STACKS=(
  farmmapping-s3-prod
  farmmapping-cloudfront-prod
  farmmapping-backend-vpc
  farmmapping-backend-alb
  farmmapping-backend-ecs
  farmmapping-backend-rds
  farmmapping-backend-app
  farmmapping-backend-schedule
)

echo "Profile: ${PROFILE}"
echo "Region:  ${REGION}"
echo

for stack in "${STACKS[@]}"; do
  echo "=== ${stack} ==="
  if ! aws --profile "${PROFILE}" --region "${REGION}" cloudformation describe-stacks \
    --stack-name "${stack}" --query "Stacks[0].StackStatus" --output text >/dev/null 2>&1; then
    echo "Status: NOT_FOUND_OR_NO_ACCESS"
    echo
    continue
  fi

  if ! detection_id="$(aws --profile "${PROFILE}" --region "${REGION}" cloudformation detect-stack-drift \
    --stack-name "${stack}" --query "StackDriftDetectionId" --output text 2>&1)"; then
    echo "DriftDetection: FAILED"
    echo "Error: ${detection_id}"
    echo
    continue
  fi

  if [ -z "${detection_id}" ] || [ "${detection_id}" = "None" ]; then
    echo "DriftDetection: FAILED_TO_START"
    echo
    continue
  fi

  status="DETECTION_IN_PROGRESS"
  stack_drift="UNKNOWN"
  reason=""
  for _ in {1..60}; do
    if ! line="$(aws --profile "${PROFILE}" --region "${REGION}" cloudformation describe-stack-drift-detection-status \
      --stack-drift-detection-id "${detection_id}" \
      --query "[DetectionStatus,StackDriftStatus,DetectionStatusReason]" \
      --output text 2>&1)"; then
      echo "DetectionStatus: FAILED"
      echo "Error: ${line}"
      status="FAILED"
      reason=""
      break
    fi
    IFS=$'\t' read -r status stack_drift reason <<< "${line}"
    if [ "${status}" != "DETECTION_IN_PROGRESS" ]; then
      break
    fi
    sleep 5
  done

  echo "DetectionStatus: ${status}"
  echo "StackDriftStatus: ${stack_drift}"
  if [ -n "${reason}" ] && [ "${reason}" != "None" ]; then
    echo "DetectionStatusReason: ${reason}"
  fi

  if [ "${stack_drift}" = "DRIFTED" ]; then
    echo "DriftedResources:"
    aws --profile "${PROFILE}" --region "${REGION}" cloudformation describe-stack-resource-drifts \
      --stack-name "${stack}" \
      --stack-resource-drift-status-filters MODIFIED DELETED \
      --query "StackResourceDrifts[].{LogicalResourceId:LogicalResourceId,ResourceType:ResourceType,Status:StackResourceDriftStatus}" \
      --output table || true
  fi
  echo
done
