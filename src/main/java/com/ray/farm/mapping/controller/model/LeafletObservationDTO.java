package com.ray.farm.mapping.controller.model;

import com.ray.farm.mapping.entity.ObservationEntity;
import com.ray.farm.mapping.model.TreeSpecies;

public record LeafletObservationDTO(long id, double lat, double lon, String iconKey, String label) {

    public static LeafletObservationDTO fromEntity(ObservationEntity e) {
        var species = TreeSpecies.valueOf(e.getTreeSpecies());
        return new LeafletObservationDTO(
                e.getId(),
                e.getLocation().getY(), // lat
                e.getLocation().getX(), // lon
                species.iconKey(),
                species.name()
        );
    }

}
