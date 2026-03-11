# Map Alignment Workflow (JPG Source)

Use this when one map layer is offset by a few meters compared to your reference map.

## 1) Collect control points

Create a CSV like `scripts/maps/gcps-template.csv`:

```csv
pixel_x,pixel_y,lon,lat
120,140,-8.000000,52.000000
...
```

- `pixel_x,pixel_y`: point in the source JPG image.
- `lon,lat`: real-world coordinate of the same point (WGS84).
- Use at least 6 points spread across corners + center.

## 2) Fix georeferencing and generate tiles

```bash
SOURCE_JPG="data/maps/my-map.jpg" \
GCP_CSV="temp/gcps/my-map.csv" \
MAP_VERSION="v3" \
TRANSFORM="tps" \
ZOOM="15-22" \
scripts/maps/fix-map-jpg-and-build-tiles.sh
```

Outputs:
- Warped raster: `temp/map-alignment/<name>-aligned-3857.tif`
- Tiles: `static/basemaps/tiles/<MAP_VERSION>/z/x/y.jpg`

## 3) Publish tiles

Use your existing upload script:

```bash
bash scripts/prod/modifications/upload-map-tiles-to-prod-bucket.sh
```

Then invalidate CloudFront as needed.

## Notes

- `TRANSFORM=tps` handles non-uniform distortion.
- If offset is a simple constant shift, `TRANSFORM=affine` is usually enough.
- Keep each correction in a new tile version (`v3`, `v4`, etc.) to avoid cache mix.
