#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-prod}"
REGION="${REGION:-eu-west-1}"

get_output() {
  local stack="$1"
  local key="$2"
  aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
    --stack-name "$stack" \
    --query "Stacks[0].Outputs[?OutputKey=='$key'].OutputValue" \
    --output text 2>/dev/null || true
}

cluster="$(get_output farmmapping-backend-ecs EcsClusterName)"
service="$(get_output farmmapping-backend-app EcsServiceName)"
asg="$(get_output farmmapping-backend-ecs AutoScalingGroupName)"
db="$(get_output farmmapping-backend-rds DbInstanceId)"

ok=true

if [[ -n "$service" && -n "$cluster" && "$service" != "None" && "$cluster" != "None" ]]; then
  desired="$(aws --profile "$PROFILE" --region "$REGION" ecs describe-services \
    --cluster "$cluster" --services "$service" \
    --query "services[0].desiredCount" --output text)"
  if [[ "$desired" != "0" ]]; then
    echo "ECS service desired count: $desired (expected 0)"
    ok=false
  else
    echo "ECS service desired count: 0"
  fi
else
  echo "ECS service/cluster not found."
  ok=false
fi

if [[ -n "$asg" && "$asg" != "None" ]]; then
  asg_desired="$(aws --profile "$PROFILE" --region "$REGION" autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$asg" \
    --query "AutoScalingGroups[0].DesiredCapacity" --output text)"
  if [[ "$asg_desired" != "0" ]]; then
    echo "ASG desired capacity: $asg_desired (expected 0)"
    ok=false
  else
    echo "ASG desired capacity: 0"
  fi
else
  echo "ASG not found."
  ok=false
fi

if [[ -n "$db" && "$db" != "None" ]]; then
  db_status="$(aws --profile "$PROFILE" --region "$REGION" rds describe-db-instances \
    --db-instance-identifier "$db" \
    --query "DBInstances[0].DBInstanceStatus" --output text)"
  if [[ "$db_status" != "stopped" ]]; then
    echo "RDS status: $db_status (expected stopped)"
    ok=false
  else
    echo "RDS status: stopped"
  fi
else
  echo "DB instance not found."
  ok=false
fi

if [[ "$ok" == "true" ]]; then
  echo "👍 All backend resources are stopped."
  exit 0
fi

echo "Backend is not fully stopped."
exit 1
