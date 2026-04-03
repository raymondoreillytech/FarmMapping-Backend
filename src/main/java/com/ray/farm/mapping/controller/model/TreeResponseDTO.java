package com.ray.farm.mapping.controller.model;

import com.ray.farm.mapping.entity.TreeEntity;

import java.time.Instant;

public record TreeResponseDTO(
        long id,
        double lat,
        double lon,
        String confirmedSpeciesCode,
        String confirmedSpeciesDisplayName,
        String iconKey,
        String statusCode,
        String statusDisplayName,
        String notes,
        Instant createdAt,
        Instant updatedAt
) {

    public static TreeResponseDTO fromEntity(TreeEntity tree) {
        return new TreeResponseDTO(
                tree.getId(),
                tree.getLocation().getY(),
                tree.getLocation().getX(),
                tree.getConfirmedSpecies().getCode(),
                tree.getConfirmedSpecies().getDisplayName(),
                tree.getConfirmedSpecies().getIconKey(),
                tree.getStatus().getCode(),
                tree.getStatus().getDisplayName(),
                tree.getNotes(),
                tree.getCreatedAt(),
                tree.getUpdatedAt()
        );
    }
}
