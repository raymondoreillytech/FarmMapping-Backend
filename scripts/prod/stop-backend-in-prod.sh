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

if [[ -n "$service" && -n "$cluster" && "$service" != "None" && "$cluster" != "None" ]]; then
  echo "Scaling ECS service to 0..."
  aws --profile "$PROFILE" --region "$REGION" ecs update-service \
    --cluster "$cluster" --service "$service" --desired-count 0 >/dev/null
else
  echo "Skipping ECS service scale-down (missing cluster/service)."
fi

if [[ -n "$asg" && "$asg" != "None" ]]; then
  echo "Scaling ASG to 0..."
  aws --profile "$PROFILE" --region "$REGION" autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$asg" --min-size 0 --max-size 0 --desired-capacity 0 >/dev/null
else
  echo "Skipping ASG scale-down (missing ASG)."
fi

if [[ -n "$db" && "$db" != "None" ]]; then
  echo "Stopping RDS instance..."
  aws --profile "$PROFILE" --region "$REGION" rds stop-db-instance \
    --db-instance-identifier "$db" >/dev/null
else
  echo "Skipping RDS stop (missing DB instance id)."
fi
