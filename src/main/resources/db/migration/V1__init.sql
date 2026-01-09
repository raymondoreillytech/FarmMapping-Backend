CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE observation (
                             id           bigserial PRIMARY KEY,
                             created_at   timestamptz NOT NULL DEFAULT now(),
                             captured_at  timestamptz NULL,

                             original_filename text NULL,
                             content_type      text NULL,

    -- store the original image in DB (prototype approach)
                             image_bytes  bytea NOT NULL,
                             tree_species      text NOT NULL,

    -- PostGIS point in WGS84
                             location     geometry(Point, 4326) NOT NULL
);

CREATE INDEX idx_observation_location
    ON observation
    USING GIST (location);
