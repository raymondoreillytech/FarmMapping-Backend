#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-prod}"
REGION="${REGION:-eu-west-1}"
DISTRIBUTION_ID="${DISTRIBUTION_ID:-E7UL8RPSQC2O9}"

# Prefer py -m awscli on Windows/Git Bash for reliable launcher behavior.
if [[ -n "${AWS_CLI:-}" ]]; then
  AWS_CMD=("$AWS_CLI")
elif command -v py >/dev/null 2>&1; then
  AWS_CMD=(py -m awscli)
elif command -v aws >/dev/null 2>&1; then
  AWS_CMD=(aws)
elif command -v aws.cmd >/dev/null 2>&1; then
  AWS_CMD=(aws.cmd)
else
  echo "aws CLI not found in PATH."
  exit 2
fi

paths=("/index.html" "/assets/*")
if [[ -n "${PATHS:-}" ]]; then
  read -r -a paths <<< "${PATHS}"
fi

MSYS2_ARG_CONV_EXCL="*" "${AWS_CMD[@]}" --profile "$PROFILE" --region "$REGION" cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "${paths[@]}"
