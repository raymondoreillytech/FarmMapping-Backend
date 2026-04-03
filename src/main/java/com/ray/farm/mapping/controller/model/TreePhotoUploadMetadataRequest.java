package com.ray.farm.mapping.controller.model;

import java.time.Instant;
import java.util.List;

public record TreePhotoUploadMetadataRequest(
        String uploadedByUserKey,
        Boolean isPrimary,
        String rawTopSpeciesCode,
        Double rawTopConfidence,
        String finalPredictedSpeciesCode,
        Double finalPredictionConfidence,
        Boolean unknownPrediction,
        String modelVersion,
        List<TreePredictionMetadataItemRequest> topPredictionsJson,
        Instant capturedAt
) {

    public static TreePhotoUploadMetadataRequest empty() {
        return new TreePhotoUploadMetadataRequest(null, null, null, null, null, null, null, null, null, null);
    }
}
