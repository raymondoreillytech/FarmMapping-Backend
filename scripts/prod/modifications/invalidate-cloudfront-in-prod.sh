#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-prod}"
REGION="${REGION:-eu-west-1}"
DISTRIBUTION_ID="${DISTRIBUTION_ID:-E7UL8RPSQC2O9}"
AWS_CLI="${AWS_CLI:-aws.cmd}"

paths=("/*")
if [[ -n "${PATHS:-}" ]]; then
  read -r -a paths <<< "${PATHS}"
fi

MSYS2_ARG_CONV_EXCL="*" MSYS_NO_PATHCONV=1 "$AWS_CLI" --profile "$PROFILE" --region "$REGION" cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "${paths[@]}"
