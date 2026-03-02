#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/map_processing/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/map_processing/run-overnight-all.sh

Behavior:
  - Runs stage-10 -> stage-20 -> stage-30 -> stage-40 sequentially for:
    - Aug25 (publish v2)
    - Dec25 (publish v3)
    - Jan26 (publish v4)
  - Continues to next map if one map fails.
  - Exits non-zero if any map failed.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ensure_dir "$LOGS_DIR"
ensure_dir "$LOGS_DIR/batch"
MASTER_LOG="$LOGS_DIR/batch/run-overnight-all.log"

STAGE10="$SCRIPT_DIR/stage-10-georeference.sh"
STAGE20="$SCRIPT_DIR/stage-20-mask-clip.sh"
STAGE30="$SCRIPT_DIR/stage-30-generate-tiles.sh"
STAGE40="$SCRIPT_DIR/stage-40-publish-webtiles-to-static.sh"

for f in "$STAGE10" "$STAGE20" "$STAGE30" "$STAGE40"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing required script: $f" >&2
    exit 1
  fi
done

run_stage_capture_last_line() {
  local label="$1"
  shift
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/run_overnight_${label// /_}_XXXXXX.log")"

  set +e
  # Stream stage output to console/logs via stderr so command substitution
  # captures only the final path we print on stdout below.
  "$@" 2>&1 | tee -a "$MASTER_LOG" | tee "$tmp" >&2
  local status="${PIPESTATUS[0]}"
  set -e

  if [[ "$status" -ne 0 ]]; then
    rm -f "$tmp"
    return "$status"
  fi

  awk 'NF { line=$0 } END { if (line != "") print line }' "$tmp" | tr -d '\r'
  rm -f "$tmp"
}

process_map() {
  local job="$1"
  local version="$2"

  local source="$SOURCE_DIR/$job/${job}_map.tif"
  local points="$POINTS_DIR/${job}.points"

  log_note "$MASTER_LOG" "============================================================"
  log_note "$MASTER_LOG" "Starting map: $job -> $version"
  log_note "$MASTER_LOG" "Source: $source"
  log_note "$MASTER_LOG" "Points: $points"

  if [[ ! -f "$source" ]]; then
    log_note "$MASTER_LOG" "ERROR: Missing source TIFF: $source"
    return 1
  fi
  if [[ ! -f "$points" ]]; then
    log_note "$MASTER_LOG" "ERROR: Missing points file: $points"
    return 1
  fi

  local georef_out
  georef_out="$(run_stage_capture_last_line "stage10_${job}" bash "$STAGE10" --source "$source" --points "$points")" || {
    log_note "$MASTER_LOG" "ERROR: stage-10 failed for $job"
    return 1
  }

  local clipped_out
  clipped_out="$(run_stage_capture_last_line "stage20_${job}" bash "$STAGE20" --georef "$georef_out")" || {
    log_note "$MASTER_LOG" "ERROR: stage-20 failed for $job"
    return 1
  }

  local tiles_out
  tiles_out="$(run_stage_capture_last_line "stage30_${job}" bash "$STAGE30" --clipped "$clipped_out")" || {
    log_note "$MASTER_LOG" "ERROR: stage-30 failed for $job"
    return 1
  }

  local publish_out
  publish_out="$(run_stage_capture_last_line "stage40_${job}" bash "$STAGE40" --tiles-dir "$tiles_out" --version "$version")" || {
    log_note "$MASTER_LOG" "ERROR: stage-40 failed for $job"
    return 1
  }

  log_note "$MASTER_LOG" "SUCCESS: $job completed. Published to $publish_out"
  return 0
}

failures=0
successes=0

if process_map "Aug25" "v2"; then
  successes=$((successes + 1))
else
  failures=$((failures + 1))
fi

if process_map "Dec25" "v3"; then
  successes=$((successes + 1))
else
  failures=$((failures + 1))
fi

if process_map "Jan26" "v4"; then
  successes=$((successes + 1))
else
  failures=$((failures + 1))
fi

log_note "$MASTER_LOG" "============================================================"
log_note "$MASTER_LOG" "Overnight batch complete: successes=$successes failures=$failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

exit 0
