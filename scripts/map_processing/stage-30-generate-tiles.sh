#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/map_processing/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/map_processing/stage-30-generate-tiles.sh --clipped <clipped_tif> [options]

Options:
  --zoom <min-max>          Zoom range (default: 17-23)
  --tile-size <px>          Tile size in pixels (default: 256)
  --jpeg-quality <0-100>    JPEG quality (default: 90)
  --jpeg-bg <white|black>   Deprecated. Native tiling uses transparent white background.
  --build-overviews         Build overviews (2,4,8,16,32) on input before tiling

Notes:
  - Processes one map only.
  - Output folder: C:/Tech/projects/maps/web_tiles/<job>_tiles
  - Uses QGIS native XYZ renderer (`native:tilesxyzdirectory`) via `python-qgis`.
  - This matches the manual QGIS approach used in successful runs.
EOF
}

CLIPPED_PATH=""
ZOOM_RANGE="$DEFAULT_ZOOM"
TILE_SIZE="$DEFAULT_TILE_SIZE"
JPEG_QUALITY="$DEFAULT_JPEG_QUALITY"
JPEG_BG="white"
BUILD_OVERVIEWS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clipped)
      CLIPPED_PATH="${2:-}"
      shift 2
      ;;
    --zoom)
      ZOOM_RANGE="${2:-}"
      shift 2
      ;;
    --tile-size)
      TILE_SIZE="${2:-}"
      shift 2
      ;;
    --jpeg-quality)
      JPEG_QUALITY="${2:-}"
      shift 2
      ;;
    --jpeg-bg)
      JPEG_BG="${2:-}"
      shift 2
      ;;
    --build-overviews)
      BUILD_OVERVIEWS=true
      shift
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

if [[ -z "$CLIPPED_PATH" ]]; then
  echo "Missing required argument: --clipped" >&2
  usage
  exit 1
fi

CLIPPED_PATH="$(abs_path "$CLIPPED_PATH")"
if [[ ! -f "$CLIPPED_PATH" ]]; then
  echo "Clipped TIFF not found: $CLIPPED_PATH" >&2
  exit 1
fi

JOB_NAME="$(derive_job_name_from_stage_file "$CLIPPED_PATH")"
ensure_dir "$WEB_TILES_DIR"
ensure_dir "$LOGS_DIR"
LOG_FILE="$(stage_log_path "$JOB_NAME" "stage-30-generate-tiles")"

require_cmd gdalsrsinfo || fail_with_log "$LOG_FILE" "gdalsrsinfo is required in PATH."
require_cmd gdalinfo || fail_with_log "$LOG_FILE" "gdalinfo is required in PATH."

if "$BUILD_OVERVIEWS"; then
  require_cmd gdaladdo || fail_with_log "$LOG_FILE" "gdaladdo is required for --build-overviews."
fi

shopt -s nocasematch
if [[ "$JPEG_BG" != "white" && "$JPEG_BG" != "black" ]]; then
  shopt -u nocasematch
  fail_with_log "$LOG_FILE" "Invalid --jpeg-bg '$JPEG_BG'. Use 'white' or 'black'."
fi
if [[ "$JPEG_BG" == "black" ]]; then
  shopt -u nocasematch
  fail_with_log "$LOG_FILE" "--jpeg-bg black is unsupported with the native QGIS renderer in this stage."
fi
JPEG_BG="white"
shopt -u nocasematch

if [[ "$ZOOM_RANGE" =~ ^([0-9]+)-([0-9]+)$ ]]; then
  ZOOM_MIN="${BASH_REMATCH[1]}"
  ZOOM_MAX="${BASH_REMATCH[2]}"
elif [[ "$ZOOM_RANGE" =~ ^([0-9]+)$ ]]; then
  ZOOM_MIN="${BASH_REMATCH[1]}"
  ZOOM_MAX="${BASH_REMATCH[1]}"
else
  fail_with_log "$LOG_FILE" "Invalid --zoom '$ZOOM_RANGE'. Expected format like 17-23 or 20."
fi

if (( 10#$ZOOM_MIN > 10#$ZOOM_MAX )); then
  fail_with_log "$LOG_FILE" "Invalid --zoom '$ZOOM_RANGE'. Minimum zoom must be <= maximum zoom."
fi

CLIPPED_EPSG="$(get_raster_epsg "$CLIPPED_PATH")"
if [[ "$CLIPPED_EPSG" != "$EXPECTED_EPSG" ]]; then
  fail_with_log "$LOG_FILE" "Clipped raster CRS is $CLIPPED_EPSG, expected $EXPECTED_EPSG."
fi

OUTPUT_BASE="$WEB_TILES_DIR/${JOB_NAME}_tiles"
OUTPUT_PATH="$(next_available_path "$OUTPUT_BASE")"
ensure_dir "$OUTPUT_PATH"

IN_NATIVE="$(native_path "$CLIPPED_PATH")"
OUT_NATIVE="$(native_path "$OUTPUT_PATH")"

if "$BUILD_OVERVIEWS"; then
  run_logged "$LOG_FILE" gdaladdo -r average "$IN_NATIVE" 2 4 8 16 32
fi

OSGEO4W_BAT="${OSGEO4W_BAT:-/c/Users/${USERNAME:-${USER:-}}/AppData/Local/Programs/OSGeo4W/OSGeo4W.bat}"
OSGEO4W_BAT="$(abs_path "$OSGEO4W_BAT")"
if [[ ! -f "$OSGEO4W_BAT" ]]; then
  fail_with_log "$LOG_FILE" "OSGeo4W launcher not found: $OSGEO4W_BAT. Set OSGEO4W_BAT env var if installed elsewhere."
fi

OSGEO4W_ROOT="$(dirname "$OSGEO4W_BAT")"
PYTHON_QGIS_BAT="${PYTHON_QGIS_BAT:-$OSGEO4W_ROOT/bin/python-qgis.bat}"
PYTHON_QGIS_BAT="$(abs_path "$PYTHON_QGIS_BAT")"
if [[ ! -f "$PYTHON_QGIS_BAT" ]]; then
  fail_with_log "$LOG_FILE" "python-qgis launcher not found: $PYTHON_QGIS_BAT. Set PYTHON_QGIS_BAT env var if installed elsewhere."
fi
PYTHON_QGIS_BAT_NATIVE="$(native_path "$PYTHON_QGIS_BAT")"

TMP_QGIS_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/${JOB_NAME}_qgis_tiles_XXXXXX.py")"
TMP_QGIS_SCRIPT_NATIVE="$(native_path "$TMP_QGIS_SCRIPT")"

cleanup() {
  if [[ -f "$TMP_QGIS_SCRIPT" ]]; then
    rm -f "$TMP_QGIS_SCRIPT"
  fi
}
trap cleanup EXIT

log_note "$LOG_FILE" "Starting stage-30 tile generation for job=$JOB_NAME"
log_note "$LOG_FILE" "Input clipped TIFF: $CLIPPED_PATH"
log_note "$LOG_FILE" "Output tiles dir: $OUTPUT_PATH"
log_note "$LOG_FILE" "Zoom range: $ZOOM_MIN-$ZOOM_MAX | Tile size: $TILE_SIZE | JPEG quality: $JPEG_QUALITY | Build overviews: $BUILD_OVERVIEWS"
log_note "$LOG_FILE" "Renderer: QGIS native:tilesxyzdirectory via python-qgis."
log_note "$LOG_FILE" "Background color: transparent white (rgba(255,255,255,0.0))"

cat > "$TMP_QGIS_SCRIPT" <<PYEOF
import os
import sys

from qgis.core import QgsApplication, QgsProject, QgsRasterLayer
from qgis.analysis import QgsNativeAlgorithms

# Ensure QGIS Processing plugin is discoverable in standalone python-qgis runs.
plugin_candidates = []
qgis_prefix = os.environ.get("QGIS_PREFIX_PATH")
if qgis_prefix:
    plugin_candidates.append(os.path.join(qgis_prefix, "python", "plugins"))
osgeo4w_root = os.environ.get("OSGEO4W_ROOT")
if osgeo4w_root:
    plugin_candidates.append(os.path.join(osgeo4w_root, "apps", "qgis", "python", "plugins"))

for p in plugin_candidates:
    if p and os.path.isdir(p) and p not in sys.path:
        sys.path.append(p)

import processing
from processing.core.Processing import Processing

INPUT_RASTER = r"$IN_NATIVE"
OUTPUT_DIR = r"$OUT_NATIVE"

# Set QGIS prefix if available in environment (reduces startup warnings).
qgis_prefix = os.environ.get("QGIS_PREFIX_PATH")
if qgis_prefix:
    QgsApplication.setPrefixPath(qgis_prefix, True)

app = QgsApplication([], False)
app.initQgis()
Processing.initialize()
registry = QgsApplication.processingRegistry()
if registry.providerById("native") is None:
    registry.addProvider(QgsNativeAlgorithms())

layer = QgsRasterLayer(INPUT_RASTER, "input_raster")
if not layer.isValid():
    raise RuntimeError(f"Invalid raster layer: {INPUT_RASTER}")

project = QgsProject.instance()
project.setCrs(layer.crs())
project.addMapLayer(layer)

extent = layer.extent()
crs_authid = layer.crs().authid() or "EPSG:32629"
extent_str = f"{extent.xMinimum()},{extent.xMaximum()},{extent.yMinimum()},{extent.yMaximum()} [{crs_authid}]"

params = {
    "EXTENT": extent_str,
    "ZOOM_MIN": int($ZOOM_MIN),
    "ZOOM_MAX": int($ZOOM_MAX),
    "DPI": 96,
    "BACKGROUND_COLOR": "rgba(255,255,255,0.0)",
    "ANTIALIAS": True,
    "TILE_FORMAT": 1,
    "QUALITY": int($JPEG_QUALITY),
    "METATILESIZE": 4,
    "TILE_WIDTH": int($TILE_SIZE),
    "TILE_HEIGHT": int($TILE_SIZE),
    "TMS_CONVENTION": False,
    "HTML_TITLE": "",
    "HTML_ATTRIBUTION": "",
    "HTML_OSM": False,
    "OUTPUT_DIRECTORY": OUTPUT_DIR,
    "OUTPUT_HTML": "TEMPORARY_OUTPUT",
}

processing.run("native:tilesxyzdirectory", params)
print(OUTPUT_DIR)
app.exitQgis()
PYEOF

run_logged "$LOG_FILE" env MSYS2_ARG_CONV_EXCL='*' cmd.exe /c call "$PYTHON_QGIS_BAT_NATIVE" "$TMP_QGIS_SCRIPT_NATIVE"

if ! find "$OUTPUT_PATH" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print -quit | grep -q .; then
  fail_with_log "$LOG_FILE" "QGIS native tiling produced no tiles in: $OUTPUT_PATH"
fi

log_note "$LOG_FILE" "Completed stage-30 tile generation."
log_note "$LOG_FILE" "Output: $OUTPUT_PATH"
printf '%s\n' "$OUTPUT_PATH"
