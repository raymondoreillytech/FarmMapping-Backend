package com.ray.farm.mapping.controller.model;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.constraints.NotNull;

public record PolygonTreeSearchRequest(
        @NotNull JsonNode geoJson,
        String speciesCode,
        String statusCode
) {
}
