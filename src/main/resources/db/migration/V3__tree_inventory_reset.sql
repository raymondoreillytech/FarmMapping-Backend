CREATE EXTENSION IF NOT EXISTS postgis;

DROP TABLE IF EXISTS tree_photo CASCADE;
DROP TABLE IF EXISTS tree CASCADE;
DROP TABLE IF EXISTS species CASCADE;
DROP TABLE IF EXISTS tree_status CASCADE;
DROP TABLE IF EXISTS observation CASCADE;

CREATE TABLE species (
    code             text PRIMARY KEY,
    display_name     text NOT NULL,
    scientific_name  text NULL,
    icon_key         text NOT NULL,
    is_unknown       boolean NOT NULL DEFAULT false,
    active           boolean NOT NULL DEFAULT true,
    sort_order       integer NOT NULL DEFAULT 0,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tree_status (
    code             text PRIMARY KEY,
    display_name     text NOT NULL,
    active           boolean NOT NULL DEFAULT true,
    sort_order       integer NOT NULL DEFAULT 0,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tree (
    id                       bigserial PRIMARY KEY,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    created_by_user_key      text NOT NULL DEFAULT 'guest',
    updated_by_user_key      text NOT NULL DEFAULT 'guest',
    created_by_ip            inet NULL,
    updated_by_ip            inet NULL,
    confirmed_species_code   text NOT NULL REFERENCES species(code),
    status_code              text NOT NULL REFERENCES tree_status(code),
    notes                    text NULL,
    location                 geometry(Point, 4326) NOT NULL
);

CREATE TABLE tree_photo (
    id                           bigserial PRIMARY KEY,
    tree_id                      bigint NOT NULL REFERENCES tree(id) ON DELETE CASCADE,
    created_at                   timestamptz NOT NULL DEFAULT now(),
    captured_at                  timestamptz NULL,
    original_filename            text NULL,
    content_type                 text NULL,
    size_bytes                   bigint NOT NULL,
    s3_bucket                    text NOT NULL,
    s3_key                       text NOT NULL,
    exif_location                geometry(Point, 4326) NULL,
    uploaded_by_user_key         text NOT NULL DEFAULT 'guest',
    uploaded_by_ip               inet NULL,
    is_primary                   boolean NOT NULL DEFAULT false,
    raw_top_species_code         text NULL REFERENCES species(code),
    raw_top_confidence           double precision NULL,
    final_predicted_species_code text NULL REFERENCES species(code),
    final_prediction_confidence  double precision NULL,
    is_unknown_prediction        boolean NOT NULL DEFAULT false,
    model_version                text NULL,
    top_predictions_json         jsonb NULL,
    CONSTRAINT chk_tree_photo_size_non_negative CHECK (size_bytes >= 0),
    CONSTRAINT chk_raw_top_confidence_range CHECK (raw_top_confidence IS NULL OR (raw_top_confidence >= 0 AND raw_top_confidence <= 1)),
    CONSTRAINT chk_final_prediction_confidence_range CHECK (final_prediction_confidence IS NULL OR (final_prediction_confidence >= 0 AND final_prediction_confidence <= 1))
);

CREATE UNIQUE INDEX uq_tree_photo_s3_object
    ON tree_photo (s3_bucket, s3_key);

CREATE UNIQUE INDEX uq_tree_photo_primary_per_tree
    ON tree_photo (tree_id)
    WHERE is_primary;

CREATE INDEX idx_tree_location
    ON tree
    USING GIST (location);

CREATE INDEX idx_tree_species_code
    ON tree (confirmed_species_code);

CREATE INDEX idx_tree_status_code
    ON tree (status_code);

CREATE INDEX idx_tree_photo_tree_id
    ON tree_photo (tree_id);

CREATE INDEX idx_tree_photo_exif_location
    ON tree_photo
    USING GIST (exif_location);

INSERT INTO species (code, display_name, scientific_name, icon_key, is_unknown, active, sort_order)
VALUES
    ('unknown', 'Unknown', NULL, 'UnknownTreeIcon', true, true, 0),
    ('alder', 'Alder', NULL, 'UnknownTreeIcon', false, true, 10),
    ('ash', 'Ash', NULL, 'UnknownTreeIcon', false, true, 20),
    ('atlas_cedar', 'Atlas Cedar', NULL, 'UnknownTreeIcon', false, true, 30),
    ('maritime_pine', 'Maritime Pine', NULL, 'UnknownTreeIcon', false, true, 40),
    ('med_cypress', 'Mediterranean Cypress', NULL, 'UnknownTreeIcon', false, true, 50),
    ('medronheiro', 'Medronheiro', NULL, 'UnknownTreeIcon', false, true, 60),
    ('oak', 'Oak', NULL, 'OakIcon', false, true, 70),
    ('olive', 'Olive', NULL, 'UnknownTreeIcon', false, true, 80),
    ('stone_pine', 'Stone Pine', NULL, 'UnknownTreeIcon', false, true, 90),
    ('white_willow', 'White Willow', NULL, 'UnknownTreeIcon', false, true, 100);

INSERT INTO tree_status (code, display_name, active, sort_order)
VALUES
    ('active', 'Active', true, 10),
    ('dead', 'Dead', true, 20),
    ('removed', 'Removed', true, 30),
    ('needs_review', 'Needs Review', true, 40);
