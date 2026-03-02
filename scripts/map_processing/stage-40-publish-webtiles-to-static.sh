#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/map_processing/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/map_processing/stage-40-publish-webtiles-to-static.sh \
    --tiles-dir <tiles_dir> \
    --version <vN>

Behavior:
  - Publishes exactly one tiles directory into one target version folder.
  - Deletes only the selected target version folder (example: v0), then copies files.
  - Does not touch any other version folders.
EOF
}

TILES_DIR=""
VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tiles-dir)
      TILES_DIR="${2:-}"
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
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

TARGET_ROOT="${TARGET_ROOT:-$REPO_ROOT/static/basemaps/tiles}"
ensure_dir "$LOGS_DIR"
PUBLISH_LOG_DIR="$LOGS_DIR/publish"
ensure_dir "$PUBLISH_LOG_DIR"
LOG_FILE="$PUBLISH_LOG_DIR/stage-40-publish-webtiles-to-static.log"

if [[ -z "$TILES_DIR" ]]; then
  fail_with_log "$LOG_FILE" "Missing required argument: --tiles-dir"
fi
if [[ -z "$VERSION" ]]; then
  fail_with_log "$LOG_FILE" "Missing required argument: --version"
fi

shopt -s nocasematch
if [[ "$VERSION" =~ ^v([0-9]+)$ ]]; then
  VERSION="v${BASH_REMATCH[1]}"
else
  shopt -u nocasematch
  fail_with_log "$LOG_FILE" "Invalid --version '$VERSION'. Expected format like v0, v1, v2."
fi
shopt -u nocasematch

version_num="${VERSION#v}"
if (( 10#$version_num < 0 )); then
  fail_with_log "$LOG_FILE" "Invalid --version '$VERSION'. Version must be v0 or higher."
fi

TILES_DIR="$(abs_path "$TILES_DIR")"
TARGET_ROOT="$(abs_path "$TARGET_ROOT")"

if [[ ! -d "$TILES_DIR" ]]; then
  fail_with_log "$LOG_FILE" "Tiles directory not found: $TILES_DIR"
fi

ensure_dir "$TARGET_ROOT"

log_note "$LOG_FILE" "Starting stage-40 publish"
log_note "$LOG_FILE" "Source tiles dir: $TILES_DIR"
log_note "$LOG_FILE" "Target static tiles dir: $TARGET_ROOT"
log_note "$LOG_FILE" "Target version: $VERSION"

if ! find "$TILES_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print -quit | grep -q .; then
  fail_with_log "$LOG_FILE" "Tile directory has no image tiles: $TILES_DIR"
fi

DEST_DIR="$TARGET_ROOT/$VERSION"
if [[ -d "$DEST_DIR" ]]; then
  log_note "$LOG_FILE" "Removing existing target folder: $DEST_DIR"
  rm -rf "$DEST_DIR"
fi
ensure_dir "$DEST_DIR"

log_note "$LOG_FILE" "Publishing $(basename "$TILES_DIR") -> $VERSION"
cp -a "$TILES_DIR"/. "$DEST_DIR"/

log_note "$LOG_FILE" "Completed stage-40 publish."
printf '%s\n' "$DEST_DIR"
