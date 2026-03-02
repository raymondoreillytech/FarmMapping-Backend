#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/map_processing/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/map_processing/stage-99-verify-tiles.sh --tiles-dir <tiles_dir> [--zoom <min-max>]

Checks:
  - Folder exists and has tile images
  - z/x/y image path format is valid
  - x and y are in valid range for z
  - Expected zoom levels exist
  - Sample image files are non-zero bytes
EOF
}

TILES_DIR=""
ZOOM_RANGE="$DEFAULT_ZOOM"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tiles-dir)
      TILES_DIR="${2:-}"
      shift 2
      ;;
    --zoom)
      ZOOM_RANGE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TILES_DIR" ]]; then
  echo "Missing required argument: --tiles-dir" >&2
  usage
  exit 1
fi

TILES_DIR="$(abs_path "$TILES_DIR")"
if [[ ! -d "$TILES_DIR" ]]; then
  echo "Tiles directory not found: $TILES_DIR" >&2
  exit 1
fi

JOB_NAME="$(derive_job_name_from_stage_file "$TILES_DIR")"
ensure_dir "$LOGS_DIR"
LOG_FILE="$(stage_log_path "$JOB_NAME" "stage-99-verify-tiles")"

if [[ ! "$ZOOM_RANGE" =~ ^([0-9]+)-([0-9]+)$ ]]; then
  fail_with_log "$LOG_FILE" "Invalid zoom range format: $ZOOM_RANGE (expected min-max, e.g. 17-23)."
fi
ZMIN="${BASH_REMATCH[1]}"
ZMAX="${BASH_REMATCH[2]}"
if (( ZMIN > ZMAX )); then
  fail_with_log "$LOG_FILE" "Invalid zoom range: $ZOOM_RANGE"
fi

log_note "$LOG_FILE" "Starting stage-99 verify"
log_note "$LOG_FILE" "Tiles dir: $TILES_DIR"
log_note "$LOG_FILE" "Expected zoom range: $ZOOM_RANGE"

declare -A ZOOM_COUNTS=()
TOTAL_FILES=0
INVALID_PATHS=0
INVALID_RANGES=0
SAMPLE_CHECKED=0
SAMPLE_ZERO_BYTES=0

while IFS= read -r -d '' file; do
  TOTAL_FILES=$((TOTAL_FILES + 1))
  rel="${file#$TILES_DIR/}"

  if [[ ! "$rel" =~ ^([0-9]+)/([0-9]+)/([0-9]+)\.(png|jpg|jpeg)$ ]]; then
    INVALID_PATHS=$((INVALID_PATHS + 1))
    continue
  fi

  z="${BASH_REMATCH[1]}"
  x="${BASH_REMATCH[2]}"
  y="${BASH_REMATCH[3]}"

  n=$((1 << z))
  if (( x < 0 || y < 0 || x >= n || y >= n )); then
    INVALID_RANGES=$((INVALID_RANGES + 1))
  fi

  ZOOM_COUNTS["$z"]=$(( ${ZOOM_COUNTS["$z"]:-0} + 1 ))

  if (( SAMPLE_CHECKED < 25 )); then
    SAMPLE_CHECKED=$((SAMPLE_CHECKED + 1))
    size="$(stat -c '%s' "$file" 2>/dev/null || wc -c < "$file")"
    if (( size <= 0 )); then
      SAMPLE_ZERO_BYTES=$((SAMPLE_ZERO_BYTES + 1))
    fi
  fi
done < <(find "$TILES_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0)

if (( TOTAL_FILES == 0 )); then
  fail_with_log "$LOG_FILE" "No tile image files found in: $TILES_DIR"
fi

for (( z = ZMIN; z <= ZMAX; z++ )); do
  if [[ -z "${ZOOM_COUNTS["$z"]:-}" ]]; then
    fail_with_log "$LOG_FILE" "Missing expected zoom level directory/content: z=$z"
  fi
done

if (( INVALID_PATHS > 0 )); then
  fail_with_log "$LOG_FILE" "Found $INVALID_PATHS files not matching z/x/y.(png|jpg|jpeg) layout."
fi

if (( INVALID_RANGES > 0 )); then
  fail_with_log "$LOG_FILE" "Found $INVALID_RANGES tiles with out-of-range x/y for their z."
fi

if (( SAMPLE_ZERO_BYTES > 0 )); then
  fail_with_log "$LOG_FILE" "Found $SAMPLE_ZERO_BYTES zero-byte files in sampled tiles."
fi

log_note "$LOG_FILE" "Verification passed."
log_note "$LOG_FILE" "Total tiles: $TOTAL_FILES"
for z in "${!ZOOM_COUNTS[@]}"; do
  log_note "$LOG_FILE" "z=$z count=${ZOOM_COUNTS["$z"]}"
done
printf '%s\n' "$TILES_DIR"

