package com.ray.farm.mapping.controller.model;

import com.ray.farm.mapping.entity.SpeciesEntity;

public record SpeciesLookupDTO(
        String code,
        String displayName,
        String scientificName,
        String iconKey,
        boolean unknown,
        boolean active,
        int sortOrder
) {

    public static SpeciesLookupDTO fromEntity(SpeciesEntity species) {
        return new SpeciesLookupDTO(
                species.getCode(),
                species.getDisplayName(),
                species.getScientificName(),
                species.getIconKey(),
                species.isUnknown(),
                species.isActive(),
                species.getSortOrder()
        );
    }
}
