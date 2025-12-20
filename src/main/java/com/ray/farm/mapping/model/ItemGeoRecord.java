package com.ray.farm.mapping.model;


import lombok.Getter;
import lombok.Setter;
import org.locationtech.jts.geom.Point;

@Setter
@Getter
public class ItemGeoRecord {

    private Point location;
    private TreeSpecies treeSpecies;

    public ItemGeoRecord(Point location) {
        this.location = location;
    }
}
