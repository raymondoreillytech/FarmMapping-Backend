#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-prod}"
REGION="${REGION:-eu-west-1}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG="${IMAGE_TAG:-latest}"

app_repo="$(aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
  --stack-name farmmapping-backend-app \
  --query "Stacks[0].Outputs[?OutputKey=='EcrRepositoryUri'].OutputValue" \
  --output text)"
inference_repo="$(aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
  --stack-name farmmapping-backend-app \
  --query "Stacks[0].Outputs[?OutputKey=='InferenceEcrRepositoryUri'].OutputValue" \
  --output text)"

if [[ -z "$app_repo" || "$app_repo" == "None" ]]; then
  echo "Backend ECR repo URI not found. Is farmmapping-backend-app stack deployed?"
  exit 1
fi

if [[ -z "$inference_repo" || "$inference_repo" == "None" ]]; then
  echo "Inference ECR repo URI not found. Is farmmapping-backend-app stack deployed?"
  exit 1
fi

registry="${app_repo%%/*}"

echo "Logging into ECR $registry..."
aws --profile "$PROFILE" --region "$REGION" ecr get-login-password | \
  docker login --username AWS --password-stdin "$registry" >/dev/null

echo "Building JAR..."
./mvnw clean package -DskipTests

echo "Building and pushing backend image to $app_repo:$TAG ($PLATFORM)..."
docker buildx build --platform "$PLATFORM" -t "$app_repo:$TAG" --push .

echo "Building and pushing inference image to $inference_repo:$TAG ($PLATFORM)..."
docker buildx build --platform "$PLATFORM" -t "$inference_repo:$TAG" --push ./inference-service

echo "Forcing ECS deployment..."
cluster="$(aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
  --stack-name farmmapping-backend-ecs \
  --query "Stacks[0].Outputs[?OutputKey=='EcsClusterName'].OutputValue" \
  --output text)"
service="$(aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
  --stack-name farmmapping-backend-app \
  --query "Stacks[0].Outputs[?OutputKey=='EcsServiceName'].OutputValue" \
  --output text)"

if [[ -n "$cluster" && "$cluster" != "None" && -n "$service" && "$service" != "None" ]]; then
  aws --profile "$PROFILE" --region "$REGION" ecs update-service \
    --cluster "$cluster" --service "$service" --force-new-deployment >/dev/null
  echo "Deployment triggered."
else
  echo "Skipped ECS deployment (cluster or service missing)."
fi
