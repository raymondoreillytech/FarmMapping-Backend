#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/map_processing/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/map_processing/stage-10-georeference.sh --source <source_tif> [--points <points_file>]

Notes:
  - Processes one map only.
  - Job name is derived from source filename and strips trailing "_map".
  - Default points path: C:/Tech/projects/maps/georeferenced_points_files/<job>.points
EOF
}

SOURCE_PATH=""
POINTS_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE_PATH="${2:-}"
      shift 2
      ;;
    --points)
      POINTS_PATH="${2:-}"
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

if [[ -z "$SOURCE_PATH" ]]; then
  echo "Missing required argument: --source" >&2
  usage
  exit 1
fi

SOURCE_PATH="$(abs_path "$SOURCE_PATH")"
if [[ ! -f "$SOURCE_PATH" ]]; then
  echo "Source TIFF not found: $SOURCE_PATH" >&2
  exit 1
fi

JOB_NAME="$(derive_job_name_from_source "$SOURCE_PATH")"

if [[ -z "$POINTS_PATH" ]]; then
  POINTS_PATH="$POINTS_DIR/${JOB_NAME}.points"
fi
POINTS_PATH="$(abs_path "$POINTS_PATH")"
if [[ ! -f "$POINTS_PATH" ]]; then
  echo "QGIS points file not found: $POINTS_PATH" >&2
  exit 1
fi

ensure_dir "$GEOREF_DIR"
ensure_dir "$LOGS_DIR"
LOG_FILE="$(stage_log_path "$JOB_NAME" "stage-10-georeference")"

require_cmd gdal_translate || fail_with_log "$LOG_FILE" "gdal_translate is required in PATH."
require_cmd gdalwarp || fail_with_log "$LOG_FILE" "gdalwarp is required in PATH."
require_cmd gdalsrsinfo || fail_with_log "$LOG_FILE" "gdalsrsinfo is required in PATH."
require_cmd gdalinfo || fail_with_log "$LOG_FILE" "gdalinfo is required in PATH."

SRC_EPSG="$(get_raster_epsg "$SOURCE_PATH")"
if [[ "$SRC_EPSG" != "$EXPECTED_EPSG" ]]; then
  fail_with_log "$LOG_FILE" "Source CRS is $SRC_EPSG, expected $EXPECTED_EPSG. Aborting."
fi

SIZE_LINE="$(gdalinfo "$(native_path "$SOURCE_PATH")" 2>/dev/null | sed -n 's/^Size is[[:space:]]*\([0-9]\+\),[[:space:]]*\([0-9]\+\).*/\1 \2/p' | head -n1)"
if [[ -z "$SIZE_LINE" ]]; then
  fail_with_log "$LOG_FILE" "Unable to read source raster size from gdalinfo."
fi
read -r RASTER_SIZE_X RASTER_SIZE_Y <<< "$SIZE_LINE"

ORIGIN_LINE="$(gdalinfo "$(native_path "$SOURCE_PATH")" 2>/dev/null | sed -n 's/^Origin = (\([^,]*\),\([^)]*\)).*/\1 \2/p' | head -n1)"
if [[ -z "$ORIGIN_LINE" ]]; then
  fail_with_log "$LOG_FILE" "Unable to read source raster origin from gdalinfo."
fi
read -r ORIGIN_X ORIGIN_Y <<< "$ORIGIN_LINE"

PIXEL_LINE="$(gdalinfo "$(native_path "$SOURCE_PATH")" 2>/dev/null | sed -n 's/^Pixel Size = (\([^,]*\),\([^)]*\)).*/\1 \2/p' | head -n1)"
if [[ -z "$PIXEL_LINE" ]]; then
  fail_with_log "$LOG_FILE" "Unable to read source raster pixel size from gdalinfo."
fi
read -r PIXEL_SIZE_X PIXEL_SIZE_Y <<< "$PIXEL_LINE"

if [[ "$PIXEL_SIZE_X" == "0" || "$PIXEL_SIZE_Y" == "0" ]]; then
  fail_with_log "$LOG_FILE" "Invalid raster pixel size from source TIFF: ($PIXEL_SIZE_X,$PIXEL_SIZE_Y)."
fi

log_note "$LOG_FILE" "Starting stage-10 georeference for job=$JOB_NAME"
log_note "$LOG_FILE" "Source: $SOURCE_PATH"
log_note "$LOG_FILE" "Points: $POINTS_PATH"
log_note "$LOG_FILE" "Source raster size: ${RASTER_SIZE_X}x${RASTER_SIZE_Y}"

declare -a GCP_ARGS=()
POINT_COUNT=0
POINTS_MODE=""

is_numeric() {
  local value="$1"
  [[ "$value" =~ ^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$ ]]
}

coords_to_pixel() {
  local map_x="$1"
  local map_y="$2"
  local px
  local py

  px="$(awk -v x="$map_x" -v ox="$ORIGIN_X" -v psx="$PIXEL_SIZE_X" 'BEGIN { printf "%.12f", (x - ox) / psx }')"
  py="$(awk -v y="$map_y" -v oy="$ORIGIN_Y" -v psy="$PIXEL_SIZE_Y" 'BEGIN { printf "%.12f", (y - oy) / psy }')"
  printf '%s %s\n' "$px" "$py"
}

value_is_in_pixel_range() {
  local px="$1"
  local py="$2"
  awk -v px="$px" -v py="$py" -v sx="$RASTER_SIZE_X" -v sy="$RASTER_SIZE_Y" '
    BEGIN {
      okx=(px >= -2 && px <= sx + 2)
      oky=(py >= -2 && py <= sy + 2)
      if (okx && oky) exit 0
      exit 1
    }'
}

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="${raw_line%$'\r'}"
  line="$(trim "$line")"

  if [[ -z "$line" || "$line" == \#* ]]; then
    continue
  fi

  IFS=',' read -r c1 c2 c3 c4 _rest <<< "$line"
  c1="$(trim "${c1:-}")"
  c2="$(trim "${c2:-}")"
  c3="$(trim "${c3:-}")"
  c4="$(trim "${c4:-}")"

  shopt -s nocasematch
  if [[ "$c1" == "mapX" || "$c1" == "mapx" ]]; then
    if [[ "$c3" == "sourceX" || "$c3" == "sourcex" ]]; then
      POINTS_MODE="source_coords"
    elif [[ "$c3" == "pixelX" || "$c3" == "pixelx" ]]; then
      POINTS_MODE="pixel_coords"
    fi
    shopt -u nocasematch
    continue
  fi
  shopt -u nocasematch

  if [[ -z "$c1" || -z "$c2" || -z "$c3" || -z "$c4" ]]; then
    continue
  fi

  if ! is_numeric "$c1" || ! is_numeric "$c2" || ! is_numeric "$c3" || ! is_numeric "$c4"; then
    continue
  fi

  pixel_x="$c3"
  pixel_y="$c4"
  if [[ "$POINTS_MODE" == "source_coords" ]]; then
    read -r pixel_x pixel_y <<< "$(coords_to_pixel "$c3" "$c4")"
  elif [[ -z "$POINTS_MODE" ]]; then
    # Auto-detect if no usable header. If column 3/4 exceed raster pixel range,
    # treat them as source map coordinates and convert to pixel/line values.
    if ! value_is_in_pixel_range "$c3" "$c4"; then
      POINTS_MODE="source_coords"
      read -r pixel_x pixel_y <<< "$(coords_to_pixel "$c3" "$c4")"
    else
      POINTS_MODE="pixel_coords"
    fi
  fi

  GCP_ARGS+=(-gcp "$pixel_x" "$pixel_y" "$c1" "$c2")
  POINT_COUNT=$((POINT_COUNT + 1))
done < "$POINTS_PATH"

if (( POINT_COUNT == 0 )); then
  fail_with_log "$LOG_FILE" "No valid control points parsed from: $POINTS_PATH"
fi

if [[ -z "$POINTS_MODE" ]]; then
  POINTS_MODE="pixel_coords"
fi
log_note "$LOG_FILE" "Points mode: $POINTS_MODE"

OUTPUT_BASE="$GEOREF_DIR/${JOB_NAME}_geotransformed_map.tif"
OUTPUT_PATH="$(next_available_path "$OUTPUT_BASE")"

TMP_WITH_GCPS="$(mktemp "${TMPDIR:-/tmp}/${JOB_NAME}_with_gcps_XXXXXX.tif")"
cleanup() {
  if [[ -f "$TMP_WITH_GCPS" ]]; then
    rm -f "$TMP_WITH_GCPS"
  fi
}
trap cleanup EXIT

SRC_NATIVE="$(native_path "$SOURCE_PATH")"
TMP_NATIVE="$(native_path "$TMP_WITH_GCPS")"
OUT_NATIVE="$(native_path "$OUTPUT_PATH")"

run_logged "$LOG_FILE" gdal_translate \
  -of GTiff \
  -a_srs "$EXPECTED_EPSG" \
  "${GCP_ARGS[@]}" \
  "$SRC_NATIVE" \
  "$TMP_NATIVE"

BAND_COUNT="$(gdalinfo "$TMP_NATIVE" 2>/dev/null | sed -n 's/^Band[[:space:]]\+\([0-9]\+\).*/\1/p' | tail -n1 || true)"
if [[ -z "$BAND_COUNT" ]]; then
  fail_with_log "$LOG_FILE" "Unable to detect band count from temporary GCP raster."
fi
if (( BAND_COUNT < 3 )); then
  fail_with_log "$LOG_FILE" "Unexpected source band count ($BAND_COUNT). Expected at least 3 bands."
fi

declare -a WARP_NODATA_ARGS=()
if (( BAND_COUNT >= 4 )); then
  # Preserve white transparent background through warping for RGBA inputs.
  WARP_NODATA_ARGS=(-srcalpha -srcnodata "255 255 255 0" -dstnodata "255 255 255 0")
  log_note "$LOG_FILE" "Detected RGBA source (bands=$BAND_COUNT). Using white+alpha nodata for warp."
else
  WARP_NODATA_ARGS=(-srcnodata "255 255 255" -dstnodata "255 255 255")
  log_note "$LOG_FILE" "Detected RGB source (bands=$BAND_COUNT). Using white nodata for warp."
fi

run_logged "$LOG_FILE" gdalwarp \
  -overwrite \
  -of GTiff \
  -s_srs "$EXPECTED_EPSG" \
  -t_srs "$EXPECTED_EPSG" \
  -order 1 \
  -r cubic \
  "${WARP_NODATA_ARGS[@]}" \
  -multi \
  -wo INIT_DEST=NO_DATA \
  -wo NUM_THREADS=ALL_CPUS \
  -co TILED=YES \
  -co COMPRESS=DEFLATE \
  -co PREDICTOR=2 \
  -co BIGTIFF=IF_SAFER \
  "$TMP_NATIVE" \
  "$OUT_NATIVE"

log_note "$LOG_FILE" "Completed stage-10 georeference."
log_note "$LOG_FILE" "Output: $OUTPUT_PATH"
printf '%s\n' "$OUTPUT_PATH"
