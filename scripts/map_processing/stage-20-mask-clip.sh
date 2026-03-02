#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/map_processing/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/map_processing/stage-20-mask-clip.sh --georef <georeferenced_tif> [--mask <mask_gpkg>] [--mask-layer <layer_name>] [--background <white|black>]

Notes:
  - Processes one map only.
  - Fails if raster CRS or mask layer CRS is not EPSG:32629.
  - No reprojection is attempted in this step.
  - Matches the manual clip flow using gdalwarp -dstalpha.
  - Output is alpha-enabled GeoTIFF (outside mask is transparent).
  - --background is accepted for compatibility but ignored in this stage.
EOF
}

GEOREF_PATH=""
MASK_PATH="$MASK_GPKG"
MASK_LAYER_NAME="$MASK_LAYER"
BACKGROUND_COLOR="white"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --georef)
      GEOREF_PATH="${2:-}"
      shift 2
      ;;
    --mask)
      MASK_PATH="${2:-}"
      shift 2
      ;;
    --mask-layer)
      MASK_LAYER_NAME="${2:-}"
      shift 2
      ;;
    --background)
      BACKGROUND_COLOR="${2:-}"
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

if [[ -z "$GEOREF_PATH" ]]; then
  echo "Missing required argument: --georef" >&2
  usage
  exit 1
fi

GEOREF_PATH="$(abs_path "$GEOREF_PATH")"
MASK_PATH="$(abs_path "$MASK_PATH")"

if [[ ! -f "$GEOREF_PATH" ]]; then
  echo "Georeferenced TIFF not found: $GEOREF_PATH" >&2
  exit 1
fi
if [[ ! -f "$MASK_PATH" ]]; then
  echo "Mask file not found: $MASK_PATH" >&2
  exit 1
fi

JOB_NAME="$(derive_job_name_from_stage_file "$GEOREF_PATH")"
ensure_dir "$CLIPPED_DIR"
ensure_dir "$LOGS_DIR"
LOG_FILE="$(stage_log_path "$JOB_NAME" "stage-20-mask-clip")"

require_cmd gdalwarp || fail_with_log "$LOG_FILE" "gdalwarp is required in PATH."
require_cmd gdalsrsinfo || fail_with_log "$LOG_FILE" "gdalsrsinfo is required in PATH."
require_cmd ogrinfo || fail_with_log "$LOG_FILE" "ogrinfo is required in PATH."
require_cmd gdalinfo || fail_with_log "$LOG_FILE" "gdalinfo is required in PATH."

shopt -s nocasematch
if [[ "$BACKGROUND_COLOR" == "white" || "$BACKGROUND_COLOR" == "black" ]]; then
  # Kept for backward compatibility. This stage now always writes alpha outside mask.
  BACKGROUND_COLOR="${BACKGROUND_COLOR,,}"
else
  shopt -u nocasematch
  fail_with_log "$LOG_FILE" "Invalid --background '$BACKGROUND_COLOR'. Use 'white' or 'black'."
fi
shopt -u nocasematch

RASTER_EPSG="$(get_raster_epsg "$GEOREF_PATH")"
if [[ "$RASTER_EPSG" != "$EXPECTED_EPSG" ]]; then
  fail_with_log "$LOG_FILE" "Georeferenced raster CRS is $RASTER_EPSG, expected $EXPECTED_EPSG."
fi

MASK_NATIVE="$(native_path "$MASK_PATH")"
if ! ogrinfo -so "$MASK_NATIVE" "$MASK_LAYER_NAME" >/dev/null 2>&1; then
  fail_with_log "$LOG_FILE" "Mask layer '$MASK_LAYER_NAME' was not found in: $MASK_PATH"
fi

MASK_EPSG="$(get_vector_layer_epsg "$MASK_PATH" "$MASK_LAYER_NAME")"
if [[ "$MASK_EPSG" != "$EXPECTED_EPSG" ]]; then
  fail_with_log "$LOG_FILE" "Mask layer CRS is $MASK_EPSG, expected $EXPECTED_EPSG. No reprojection allowed."
fi

PIXEL_SIZE="$(get_raster_pixel_size "$GEOREF_PATH")"
if [[ -z "$PIXEL_SIZE" ]]; then
  fail_with_log "$LOG_FILE" "Could not read raster pixel size from: $GEOREF_PATH"
fi
read -r XRES YRES <<< "$PIXEL_SIZE"

OUTPUT_BASE="$CLIPPED_DIR/${JOB_NAME}_clipped_map.tif"
OUTPUT_PATH="$(next_available_path "$OUTPUT_BASE")"

IN_NATIVE="$(native_path "$GEOREF_PATH")"
OUT_NATIVE="$(native_path "$OUTPUT_PATH")"

log_note "$LOG_FILE" "Starting stage-20 mask clip for job=$JOB_NAME"
log_note "$LOG_FILE" "Input georeferenced TIFF: $GEOREF_PATH"
log_note "$LOG_FILE" "Mask GPKG: $MASK_PATH (layer=$MASK_LAYER_NAME)"
log_note "$LOG_FILE" "Pixel size: X=$XRES Y=$YRES"
log_note "$LOG_FILE" "Background option: $BACKGROUND_COLOR (ignored in stage-20, using -dstalpha output)"

run_logged "$LOG_FILE" gdalwarp \
  -overwrite \
  -of GTiff \
  -tr "$XRES" "$YRES" \
  -tap \
  -cutline "$MASK_NATIVE" \
  -cl "$MASK_LAYER_NAME" \
  -crop_to_cutline \
  -dstalpha \
  -oo NUM_THREADS=ALL_CPUS \
  "$IN_NATIVE" \
  "$OUT_NATIVE"

log_note "$LOG_FILE" "Completed stage-20 mask clip."
log_note "$LOG_FILE" "Output: $OUTPUT_PATH"
printf '%s\n' "$OUTPUT_PATH"
