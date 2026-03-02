# Map Processing Scripts (One Map at a Time)

These scripts implement a staged pipeline from source TIFF to web tiles.

Base folders (fixed defaults):

- `C:/Tech/projects/maps/webodm_original_maps`
- `C:/Tech/projects/maps/georeferenced_points_files`
- `C:/Tech/projects/maps/shape_file_for_masking`
- `C:/Tech/projects/maps/georeferenced_transformed_maps`
- `C:/Tech/projects/maps/mask_clipped_maps`
- `C:/Tech/projects/maps/web_tiles`
- `C:/Tech/projects/maps/logs`

Mask defaults:

- GPKG: `C:/Tech/projects/maps/shape_file_for_masking/shape_file_hill_and_flatland.gpkg`
- Layer: `shape_file_hill_and_flatland`
- Expected CRS: `EPSG:32629`

## Stage 10: Georeference

```bash
bash scripts/map_processing/stage-10-georeference.sh \
  --source "C:/Tech/projects/maps/webodm_original_maps/aug25/aug25_map.tif"
```

Default points file is inferred as:

- `C:/Tech/projects/maps/georeferenced_points_files/aug25.points`

## Stage 20: Mask/Clip

```bash
bash scripts/map_processing/stage-20-mask-clip.sh \
  --georef "C:/Tech/projects/maps/georeferenced_transformed_maps/aug25_geotransformed_map.tif"
```

Notes:
- Uses `gdalwarp -dstalpha` style clipping (matches manual workflow).
- Output clipped TIFF keeps alpha outside the mask.
- `--background` is accepted for backward compatibility but ignored in this stage.

## Stage 30: Generate Tiles

```bash
bash scripts/map_processing/stage-30-generate-tiles.sh \
  --clipped "C:/Tech/projects/maps/mask_clipped_maps/aug25_clipped_map.tif"
```

Note:

- Uses QGIS native tiler (`native:tilesxyzdirectory`) through `python-qgis`.
- QGIS background is rendered as transparent white (`rgba(255,255,255,0.0)`), matching the manual run pattern.
- Stage-30 expects clipped TIFF from stage-20 and requires a working OSGeo4W install.

If `OSGeo4W.bat` is not at the default location, set:

```bash
export OSGEO4W_BAT="/c/Users/<you>/AppData/Local/Programs/OSGeo4W/OSGeo4W.bat"
```

If `python-qgis.bat` is not at the default location, set:

```bash
export PYTHON_QGIS_BAT="/c/Users/<you>/AppData/Local/Programs/OSGeo4W/bin/python-qgis.bat"
```

Optional overviews:

```bash
bash scripts/map_processing/stage-30-generate-tiles.sh \
  --clipped "C:/Tech/projects/maps/mask_clipped_maps/aug25_clipped_map.tif" \
  --build-overviews
```

## Stage 99: Verify Tiles

```bash
bash scripts/map_processing/stage-99-verify-tiles.sh \
  --tiles-dir "C:/Tech/projects/maps/web_tiles/aug25_tiles" \
  --zoom 17-23
```

## Stage 40: Publish to Repo `static/basemaps/tiles/v*`

```bash
bash scripts/map_processing/stage-40-publish-webtiles-to-static.sh \
  --tiles-dir "C:/Tech/projects/maps/web_tiles/aug25_tiles" \
  --version v2
```

Rules:

- Publishes exactly one source tiles directory to the version you choose.
- Deletes only that target version folder first (example `static/basemaps/tiles/v2`).
- Does not delete or modify other version folders.

## Overnight Batch (Aug25 + Dec25 + Jan26)

Runs full pipeline sequentially:
- `Aug25 -> v2`
- `Dec25 -> v3`
- `Jan26 -> v4`

Command:

```bash
bash scripts/map_processing/run-overnight-all.sh
```

Behavior:
- Continues to next map if one fails.
- Returns non-zero exit code if any map failed.
- Writes master batch log to `C:/Tech/projects/maps/logs/batch/run-overnight-all.log`.

## Logging

Every stage writes logs in:

- `C:/Tech/projects/maps/logs/<job>/stage-*.log`
- Publish writes to:
  - `C:/Tech/projects/maps/logs/publish/stage-40-publish-webtiles-to-static.log`
