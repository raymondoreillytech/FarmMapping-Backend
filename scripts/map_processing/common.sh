#!/usr/bin/env bash

# Shared helpers for one-map-at-a-time processing stages.

MAPS_ROOT="${MAPS_ROOT:-/c/Tech/projects/maps}"
SOURCE_DIR="${SOURCE_DIR:-$MAPS_ROOT/webodm_original_maps}"
POINTS_DIR="${POINTS_DIR:-$MAPS_ROOT/georeferenced_points_files}"
MASK_DIR="${MASK_DIR:-$MAPS_ROOT/shape_file_for_masking}"
GEOREF_DIR="${GEOREF_DIR:-$MAPS_ROOT/georeferenced_transformed_maps}"
CLIPPED_DIR="${CLIPPED_DIR:-$MAPS_ROOT/mask_clipped_maps}"
WEB_TILES_DIR="${WEB_TILES_DIR:-$MAPS_ROOT/web_tiles}"
LOGS_DIR="${LOGS_DIR:-$MAPS_ROOT/logs}"

MASK_GPKG="${MASK_GPKG:-$MASK_DIR/shape_file_hill_and_flatland.gpkg}"
MASK_LAYER="${MASK_LAYER:-shape_file_hill_and_flatland}"
EXPECTED_EPSG="${EXPECTED_EPSG:-EPSG:32629}"

DEFAULT_ZOOM="${DEFAULT_ZOOM:-17-23}"
DEFAULT_TILE_SIZE="${DEFAULT_TILE_SIZE:-256}"
DEFAULT_JPEG_QUALITY="${DEFAULT_JPEG_QUALITY:-90}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

normalize_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$path"
  else
    printf '%s\n' "$path"
  fi
}

native_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$path"
  else
    printf '%s\n' "$path"
  fi
}

abs_path() {
  local path
  path="$(normalize_path "$1")"
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$PWD/$path"
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing command: $cmd"
    return 1
  fi
}

quote_cmd() {
  local quoted="" arg
  for arg in "$@"; do
    local q
    printf -v q '%q' "$arg"
    quoted+="$q "
  done
  printf '%s' "${quoted% }"
}

run_logged() {
  local log_file="$1"
  shift

  {
    printf '\n[%s] CMD: %s\n' "$(timestamp)" "$(quote_cmd "$@")"
    "$@"
  } 2>&1 | tee -a "$log_file"

  return "${PIPESTATUS[0]}"
}

stage_log_path() {
  local job="$1"
  local stage="$2"
  local job_log_dir="$LOGS_DIR/$job"
  ensure_dir "$job_log_dir"
  printf '%s\n' "$job_log_dir/${stage}.log"
}

log_note() {
  local log_file="$1"
  shift
  printf '[%s] %s\n' "$(timestamp)" "$*" | tee -a "$log_file"
}

fail_with_log() {
  local log_file="$1"
  shift
  printf '[%s] ERROR: %s\n' "$(timestamp)" "$*" | tee -a "$log_file" >&2
  exit 1
}

strip_duplicate_prefix() {
  local value="$1"
  if [[ "$value" =~ ^duplicate[0-9]+_(.+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '%s\n' "$value"
  fi
}

derive_job_name_from_source() {
  local source_path="$1"
  local base_name
  base_name="$(basename "$source_path")"
  local stem="${base_name%.*}"
  local job="$stem"

  shopt -s nocasematch
  if [[ "$job" =~ ^(.+)_map$ ]]; then
    job="${BASH_REMATCH[1]}"
  fi
  shopt -u nocasematch

  printf '%s\n' "$job"
}

derive_job_name_from_stage_file() {
  local stage_path="$1"
  local base_name
  base_name="$(basename "$stage_path")"
  local stem="${base_name%.*}"
  stem="$(strip_duplicate_prefix "$stem")"

  for suffix in "_geotransformed_map" "_clipped_map" "_tiles"; do
    if [[ "$stem" == *"$suffix" ]]; then
      stem="${stem%"$suffix"}"
      break
    fi
  done

  printf '%s\n' "$stem"
}

next_available_path() {
  local requested="$1"
  if [[ ! -e "$requested" ]]; then
    printf '%s\n' "$requested"
    return 0
  fi

  local dir
  dir="$(dirname "$requested")"
  local base
  base="$(basename "$requested")"

  local index=1
  local candidate
  while :; do
    candidate="$dir/duplicate${index}_$base"
    if [[ ! -e "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    index=$((index + 1))
  done
}

get_raster_epsg() {
  local raster_path="$1"
  local raster_native
  raster_native="$(native_path "$raster_path")"
  gdalsrsinfo -o epsg "$raster_native" 2>/dev/null | tr -d '\r' | grep -Eo 'EPSG:[0-9]+' | tail -n1 || true
}

get_vector_layer_epsg() {
  local vector_path="$1"
  local layer_name="$2"
  local vector_native
  vector_native="$(native_path "$vector_path")"

  local info
  info="$(ogrinfo -so "$vector_native" "$layer_name" 2>/dev/null | tr -d '\r' || true)"
  if [[ -z "$info" ]]; then
    return 0
  fi

  # Older WKT style: AUTHORITY["EPSG","32629"]
  local auth_code
  auth_code="$(printf '%s\n' "$info" \
    | sed -n 's/.*AUTHORITY\["EPSG","\([0-9]\+\)"\].*/\1/p' \
    | tail -n1 || true)"
  if [[ -n "$auth_code" ]]; then
    printf 'EPSG:%s\n' "$auth_code"
    return 0
  fi

  # Newer WKT2 style: ID["EPSG",32629]
  local id_code
  id_code="$(printf '%s\n' "$info" \
    | sed -n 's/.*ID\["EPSG",\([0-9]\+\)\].*/\1/p' \
    | tail -n1 || true)"
  if [[ -n "$id_code" ]]; then
    printf 'EPSG:%s\n' "$id_code"
    return 0
  fi

  # Metadata fallback (for example authid EPSG:32629)
  printf '%s\n' "$info" \
    | grep -Eo 'EPSG:[0-9]+' \
    | tail -n1 || true
}

get_raster_pixel_size() {
  local raster_path="$1"
  local raster_native
  raster_native="$(native_path "$raster_path")"

  gdalinfo "$raster_native" 2>/dev/null \
    | sed -n 's/.*Pixel Size = (\([^,]*\),\([^)]*\)).*/\1 \2/p' \
    | head -n1 || true
}

find_gdal2tiles_bin() {
  if command -v gdal2tiles.py >/dev/null 2>&1; then
    printf '%s\n' "gdal2tiles.py"
    return 0
  fi
  if command -v gdal2tiles >/dev/null 2>&1; then
    printf '%s\n' "gdal2tiles"
    return 0
  fi
  return 1
}

month_to_number() {
  local mon="${1,,}"
  case "$mon" in
    jan) printf '%s\n' "01" ;;
    feb) printf '%s\n' "02" ;;
    mar) printf '%s\n' "03" ;;
    apr) printf '%s\n' "04" ;;
    may) printf '%s\n' "05" ;;
    jun) printf '%s\n' "06" ;;
    jul) printf '%s\n' "07" ;;
    aug) printf '%s\n' "08" ;;
    sep) printf '%s\n' "09" ;;
    oct) printf '%s\n' "10" ;;
    nov) printf '%s\n' "11" ;;
    dec) printf '%s\n' "12" ;;
    *) return 1 ;;
  esac
}

sortable_key_from_tiles_dir_name() {
  local dir_name="$1"
  if [[ ! "$dir_name" =~ ^([A-Za-z]{3})([0-9]{2})_tiles$ ]]; then
    return 1
  fi

  local mon_abbr="${BASH_REMATCH[1]}"
  local year2="${BASH_REMATCH[2]}"
  local month_num
  month_num="$(month_to_number "$mon_abbr")" || return 1

  local year4
  year4=$((2000 + 10#$year2))
  printf '%04d%s\n' "$year4" "$month_num"
}
