#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-prod}"
REGION="${REGION:-eu-west-1}"
SCHEDULE_STACK="${SCHEDULE_STACK:-farmmapping-backend-schedule}"
HOURS="${HOURS:-168}"
METRIC_PERIOD="${METRIC_PERIOD:-3600}"

# Prevent Git Bash on Windows from rewriting CloudWatch log groups like /aws/lambda/...
if [[ -n "${MSYSTEM:-}" ]]; then
  export MSYS_NO_PATHCONV=1
fi

get_output() {
  local stack="$1"
  local key="$2"
  aws --profile "$PROFILE" --region "$REGION" cloudformation describe-stacks \
    --stack-name "$stack" \
    --query "Stacks[0].Outputs[?OutputKey=='$key'].OutputValue" \
    --output text 2>/dev/null || true
}

normalize_number() {
  local raw="${1:-}"
  if [[ -z "$raw" || "$raw" == "None" || "$raw" == "null" ]]; then
    echo 0
    return
  fi

  awk -v n="$raw" 'BEGIN { printf "%.0f", n }'
}

metric_sum() {
  local namespace="$1"
  local metric="$2"
  local dim_name="$3"
  local dim_value="$4"
  local start_time="$5"
  local end_time="$6"
  local raw

  raw="$(aws --profile "$PROFILE" --region "$REGION" cloudwatch get-metric-statistics \
    --namespace "$namespace" \
    --metric-name "$metric" \
    --dimensions "Name=${dim_name},Value=${dim_value}" \
    --statistics Sum \
    --start-time "$start_time" \
    --end-time "$end_time" \
    --period "$METRIC_PERIOD" \
    --query "sum(Datapoints[].Sum)" \
    --output text 2>/dev/null || true)"

  normalize_number "$raw"
}

utc_now() {
  if date -u "+%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    date -u "+%Y-%m-%dT%H:%M:%SZ"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))'
    return
  fi

  echo ""
}

utc_hours_ago() {
  local hours="$1"

  if date -u -d "$hours hours ago" "+%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    date -u -d "$hours hours ago" "+%Y-%m-%dT%H:%M:%SZ"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$hours" <<'PY'
import sys
from datetime import datetime, timezone, timedelta
h = int(sys.argv[1])
print((datetime.now(timezone.utc) - timedelta(hours=h)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
    return
  fi

  echo ""
}

epoch_ms_to_iso_utc() {
  local ms="$1"
  local secs=$((ms / 1000))

  if date -u -d "@$secs" "+%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    date -u -d "@$secs" "+%Y-%m-%dT%H:%M:%SZ"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$secs" <<'PY'
import sys
from datetime import datetime, timezone
s = int(sys.argv[1])
print(datetime.fromtimestamp(s, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
    return
  fi

  echo "$ms"
}

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required."
  exit 2
fi

if ! aws --profile "$PROFILE" --region "$REGION" sts get-caller-identity >/dev/null 2>&1; then
  echo "Cannot access AWS account with profile=$PROFILE region=$REGION."
  exit 2
fi

stopper_function_name="${STOPPER_FUNCTION_NAME:-$(get_output "$SCHEDULE_STACK" StopperFunctionName)}"
starter_function_name="${STARTER_FUNCTION_NAME:-$(get_output "$SCHEDULE_STACK" StarterFunctionName)}"
stop_rule_arn="${STOP_SCHEDULE_RULE_ARN:-$(get_output "$SCHEDULE_STACK" StopScheduleRuleArn)}"
start_db_rule_arn="${START_DB_SCHEDULE_RULE_ARN:-$(get_output "$SCHEDULE_STACK" StartDbScheduleRuleArn)}"
start_compute_rule_arn="${START_COMPUTE_SCHEDULE_RULE_ARN:-$(get_output "$SCHEDULE_STACK" StartComputeScheduleRuleArn)}"

if [[ -z "$stopper_function_name" || "$stopper_function_name" == "None" ]]; then
  echo "Could not resolve StopperFunctionName from stack $SCHEDULE_STACK."
  exit 1
fi

if [[ -z "$starter_function_name" || "$starter_function_name" == "None" ]]; then
  echo "Could not resolve StarterFunctionName from stack $SCHEDULE_STACK."
  exit 1
fi

if [[ -z "$stop_rule_arn" || "$stop_rule_arn" == "None" ]]; then
  echo "Could not resolve StopScheduleRuleArn from stack $SCHEDULE_STACK."
  exit 1
fi

if [[ -z "$start_db_rule_arn" || "$start_db_rule_arn" == "None" ]]; then
  echo "Could not resolve StartDbScheduleRuleArn from stack $SCHEDULE_STACK."
  exit 1
fi

if [[ -z "$start_compute_rule_arn" || "$start_compute_rule_arn" == "None" ]]; then
  echo "Could not resolve StartComputeScheduleRuleArn from stack $SCHEDULE_STACK."
  exit 1
fi

start_time="$(utc_hours_ago "$HOURS")"
end_time="$(utc_now)"

if [[ -z "$start_time" || -z "$end_time" ]]; then
  echo "Could not calculate UTC time bounds. Install GNU date or python3."
  exit 2
fi

echo "Schedule stack : $SCHEDULE_STACK"
echo "Window (UTC)   : $start_time -> $end_time"

fail=0

check_rule() {
  local label="$1"
  local rule_arn="$2"
  local function_name="$3"
  local rule_name="${rule_arn##*/}"
  local rule_state
  local schedule
  local target_count
  local events_invocations
  local events_failed

  rule_state="$(aws --profile "$PROFILE" --region "$REGION" events describe-rule \
    --name "$rule_name" \
    --query "State" \
    --output text 2>/dev/null || true)"

  schedule="$(aws --profile "$PROFILE" --region "$REGION" events describe-rule \
    --name "$rule_name" \
    --query "ScheduleExpression" \
    --output text 2>/dev/null || true)"

  target_count="$(aws --profile "$PROFILE" --region "$REGION" events list-targets-by-rule \
    --rule "$rule_name" \
    --query "length(Targets[?contains(Arn, '$function_name')])" \
    --output text 2>/dev/null || true)"

  events_invocations="$(metric_sum "AWS/Events" "Invocations" "RuleName" "$rule_name" "$start_time" "$end_time")"
  events_failed="$(metric_sum "AWS/Events" "FailedInvocations" "RuleName" "$rule_name" "$start_time" "$end_time")"

  echo
  echo "$label rule"
  echo "  name                  : $rule_name"
  echo "  schedule              : ${schedule:-UNKNOWN}"
  echo "  state                 : ${rule_state:-UNKNOWN}"
  echo "  lambda target wired   : ${target_count:-0}"
  echo "  EventBridge invokes   : $events_invocations"
  echo "  failed invokes        : $events_failed"

  if [[ "$rule_state" != "ENABLED" ]]; then
    echo "  FAIL: EventBridge rule is not ENABLED."
    fail=1
  fi

  if [[ -z "$target_count" || "$target_count" == "None" || "$target_count" == "0" ]]; then
    echo "  FAIL: EventBridge rule is not targeting $function_name."
    fail=1
  fi

  if [[ "$events_invocations" == "0" ]]; then
    echo "  WARN: No EventBridge invocations in the last $HOURS hours."
  fi

  if [[ "$events_failed" != "0" ]]; then
    echo "  FAIL: EventBridge has failed invocations."
    fail=1
  fi
}

check_lambda() {
  local label="$1"
  local function_name="$2"
  local lambda_invocations
  local lambda_errors
  local log_group
  local last_event_ms

  lambda_invocations="$(metric_sum "AWS/Lambda" "Invocations" "FunctionName" "$function_name" "$start_time" "$end_time")"
  lambda_errors="$(metric_sum "AWS/Lambda" "Errors" "FunctionName" "$function_name" "$start_time" "$end_time")"
  log_group="/aws/lambda/$function_name"
  last_event_ms="$(aws --profile "$PROFILE" --region "$REGION" logs describe-log-streams \
    --log-group-name "$log_group" \
    --order-by LastEventTime \
    --descending \
    --limit 1 \
    --query "logStreams[0].lastEventTimestamp" \
    --output text 2>/dev/null || true)"

  echo
  echo "$label lambda"
  echo "  name                  : $function_name"
  echo "  invocations           : $lambda_invocations"
  echo "  errors                : $lambda_errors"
  if [[ -n "$last_event_ms" && "$last_event_ms" != "None" ]]; then
    echo "  last log event (UTC)  : $(epoch_ms_to_iso_utc "$last_event_ms")"
  else
    echo "  last log event (UTC)  : none"
  fi

  if [[ "$lambda_invocations" == "0" ]]; then
    echo "  WARN: No Lambda invocations in the last $HOURS hours."
  fi

  if [[ "$lambda_errors" != "0" ]]; then
    echo "  FAIL: Lambda has errors."
    fail=1
  fi
}

check_rule "Stop backend" "$stop_rule_arn" "$stopper_function_name"
check_rule "Start database" "$start_db_rule_arn" "$starter_function_name"
check_rule "Start compute" "$start_compute_rule_arn" "$starter_function_name"
check_lambda "Stopper" "$stopper_function_name"
check_lambda "Starter" "$starter_function_name"

if [[ "$fail" -eq 0 ]]; then
  echo
  echo "PASS: Schedule rules are enabled and wired."
  exit 0
fi

echo
echo "FAIL: Schedule is not healthy. Investigate EventBridge/Lambda logs."
exit 1
