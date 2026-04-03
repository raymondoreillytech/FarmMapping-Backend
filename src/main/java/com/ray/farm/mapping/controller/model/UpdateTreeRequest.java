package com.ray.farm.mapping.controller.model;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;

public record UpdateTreeRequest(
        @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
        @DecimalMin("-180.0") @DecimalMax("180.0") Double lon,
        String confirmedSpeciesCode,
        String statusCode,
        String notes,
        String updatedByUserKey
) {
}
