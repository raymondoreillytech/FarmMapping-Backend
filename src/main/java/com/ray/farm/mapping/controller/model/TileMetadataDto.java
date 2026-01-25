package com.ray.farm.mapping.controller.model;

public record TileMetadataDto(
        int minZoom,
        int maxZoom,
        Bounds3857 bounds3857,
        String tileUrlTemplate
) {
    public record Bounds3857(double minX, double minY, double maxX, double maxY) {}
}
