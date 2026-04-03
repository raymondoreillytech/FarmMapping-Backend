package com.ray.farm.mapping.controller.model;

public record TreePredictionMetadataItemRequest(
        String speciesCode,
        Double confidence
) {
}
