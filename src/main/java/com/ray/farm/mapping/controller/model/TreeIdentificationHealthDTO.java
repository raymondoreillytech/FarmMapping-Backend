package com.ray.farm.mapping.controller.model;

import java.util.List;

public record TreeIdentificationHealthDTO(
        String status,
        String modelVersion,
        String modelPath,
        String labelsPath,
        String backbone,
        String device,
        int numClasses,
        List<String> classNames,
        double unknownConfidenceThreshold
) {
}
