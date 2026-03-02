#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-prod}"
REGION="${REGION:-eu-west-1}"
SCHEDULE_STACK="${SCHEDULE_STACK:-farmmapping-backend-schedule}"
HOURS="${HOURS:-168}"
METRIC_PERIOD="${METRIC_PERIOD:-3600}"

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

function_name="${STOPPER_FUNCTION_NAME:-$(get_output "$SCHEDULE_STACK" StopperFunctionName)}"
rule_arn="${STOP_SCHEDULE_RULE_ARN:-$(get_output "$SCHEDULE_STACK" StopScheduleRuleArn)}"

if [[ -z "$function_name" || "$function_name" == "None" ]]; then
  echo "Could not resolve StopperFunctionName from stack $SCHEDULE_STACK."
  exit 1
fi

if [[ -z "$rule_arn" || "$rule_arn" == "None" ]]; then
  echo "Could not resolve StopScheduleRuleArn from stack $SCHEDULE_STACK."
  exit 1
fi

rule_name="${EVENT_RULE_NAME:-${rule_arn##*/}}"
start_time="$(utc_hours_ago "$HOURS")"
end_time="$(utc_now)"

if [[ -z "$start_time" || -z "$end_time" ]]; then
  echo "Could not calculate UTC time bounds. Install GNU date or python3."
  exit 2
fi

rule_state="$(aws --profile "$PROFILE" --region "$REGION" events describe-rule \
  --name "$rule_name" \
  --query "State" \
  --output text 2>/dev/null || true)"

target_count="$(aws --profile "$PROFILE" --region "$REGION" events list-targets-by-rule \
  --rule "$rule_name" \
  --query "length(Targets[?contains(Arn, '$function_name')])" \
  --output text 2>/dev/null || true)"

events_invocations="$(metric_sum "AWS/Events" "Invocations" "RuleName" "$rule_name" "$start_time" "$end_time")"
events_failed="$(metric_sum "AWS/Events" "FailedInvocations" "RuleName" "$rule_name" "$start_time" "$end_time")"
lambda_invocations="$(metric_sum "AWS/Lambda" "Invocations" "FunctionName" "$function_name" "$start_time" "$end_time")"
lambda_errors="$(metric_sum "AWS/Lambda" "Errors" "FunctionName" "$function_name" "$start_time" "$end_time")"

echo "Schedule stack : $SCHEDULE_STACK"
echo "Rule name      : $rule_name"
echo "Lambda name    : $function_name"
echo "Window (UTC)   : $start_time -> $end_time"
echo
echo "EventBridge rule state      : ${rule_state:-UNKNOWN}"
echo "Lambda target wired         : ${target_count:-0}"
echo "EventBridge invocations     : $events_invocations"
echo "EventBridge failed invoke   : $events_failed"
echo "Lambda invocations          : $lambda_invocations"
echo "Lambda errors               : $lambda_errors"

log_group="/aws/lambda/$function_name"
last_event_ms="$(aws --profile "$PROFILE" --region "$REGION" logs describe-log-streams \
  --log-group-name "$log_group" \
  --order-by LastEventTime \
  --descending \
  --limit 1 \
  --query "logStreams[0].lastEventTimestamp" \
  --output text 2>/dev/null || true)"

if [[ -n "$last_event_ms" && "$last_event_ms" != "None" ]]; then
  echo "Last lambda log event (UTC) : $(epoch_ms_to_iso_utc "$last_event_ms")"
else
  echo "Last lambda log event (UTC) : none"
fi

fail=0

if [[ "$rule_state" != "ENABLED" ]]; then
  echo "FAIL: EventBridge rule is not ENABLED."
  fail=1
fi

if [[ -z "$target_count" || "$target_count" == "None" || "$target_count" == "0" ]]; then
  echo "FAIL: EventBridge rule is not targeting the stopper Lambda."
  fail=1
fi

if [[ "$events_invocations" == "0" ]]; then
  echo "FAIL: No EventBridge invocations in the last $HOURS hours."
  fail=1
fi

if [[ "$lambda_invocations" == "0" ]]; then
  echo "FAIL: No Lambda invocations in the last $HOURS hours."
  fail=1
fi

if [[ "$events_failed" != "0" ]]; then
  echo "FAIL: EventBridge has failed invocations."
  fail=1
fi

if [[ "$lambda_errors" != "0" ]]; then
  echo "FAIL: Stopper Lambda has errors."
  fail=1
fi

if [[ "$fail" -eq 0 ]]; then
  echo "PASS: Schedule appears to be working."
  exit 0
fi

echo "FAIL: Schedule is not healthy. Investigate EventBridge/Lambda logs."
exit 1
