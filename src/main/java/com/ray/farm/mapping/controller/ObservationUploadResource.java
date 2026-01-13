package com.ray.farm.mapping.controller;

import com.ray.farm.mapping.model.TreeSpecies;
import lombok.Data;
import org.jspecify.annotations.Nullable;

@Data
public class ObservationUploadResource {
    private TreeSpecies treeSpecies;
    private double gpsLat = 0;
    private double gpsLon = 0;
    private String originalFilename;
    private String contentType;
    private long size;
    private byte[] bytes;


    public ObservationUploadResource(@Nullable String originalFilename, @Nullable String contentType, long size, byte[] bytes,
                                     double gpsLat, double gpsLon, TreeSpecies treeSpecies) {

        this.originalFilename = originalFilename;
        this.contentType = contentType;
        this.size = size;
        this.bytes = bytes;
        this.gpsLon = gpsLon;
        this.gpsLat = gpsLat;
        this.treeSpecies = treeSpecies;
    }
}
