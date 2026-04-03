package com.ray.farm.mapping.controller.model;

import java.util.List;

public record TreeIdentificationPredictionDTO(
        String modelVersion,
        List<TreeIdentificationPredictionItemDTO> predictions,
        String rawTopPrediction,
        String topPrediction,
        double topConfidence,
        double top2Margin,
        boolean isUnknown,
        List<String> unknownReasons,
        String backbone,
        String device
) {
}
