package com.ray.farm.mapping.controller.model;

import com.ray.farm.mapping.entity.TreeEntity;

public record LeafletObservationDTO(long id, double lat, double lon, String iconKey, String label) {

    public static LeafletObservationDTO fromEntity(TreeEntity tree) {
        return new LeafletObservationDTO(
                tree.getId(),
                tree.getLocation().getY(),
                tree.getLocation().getX(),
                tree.getConfirmedSpecies().getIconKey(),
                tree.getConfirmedSpecies().getDisplayName()
        );
    }

}
