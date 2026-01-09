package com.ray.farm.mapping.service;

import com.ray.farm.mapping.controller.ObservationUploadResource;
import com.ray.farm.mapping.controller.model.LeafletObservationDTO;
import com.ray.farm.mapping.controller.model.PhotoSubmissionDTO;
import com.ray.farm.mapping.entity.ObservationEntity;
import com.ray.farm.mapping.entity.ObservationRepository;
import lombok.AllArgsConstructor;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@AllArgsConstructor
public class TreePhotoProcessorService {


    public static final int WGS84_SRID = 4326; //Standard for lon, lat usage, doesnt need to mimic basemap projection
    private static final GeometryFactory geometryFactory =
            new GeometryFactory(new PrecisionModel(), WGS84_SRID);


    private final ObservationRepository repo;

    public static Point createPoint(double lat, double lon) {
        Point p = geometryFactory.createPoint(new Coordinate(lon, lat));
        p.setSRID(WGS84_SRID);
        return p;
    }

    public PhotoSubmissionDTO createFromPhoto(ObservationUploadResource observationUploadResource) {


        // 2) persist
        ObservationEntity e = new ObservationEntity();
        e.setOriginalFilename(observationUploadResource.getOriginalFilename());
        e.setContentType(observationUploadResource.getContentType());
        e.setImageBytes(observationUploadResource.getBytes());
        e.setLocation(createPoint(observationUploadResource.getGpsLat(), observationUploadResource.getGpsLon()));
        e.setTreeSpecies(observationUploadResource.getTreeSpecies().toString());
        // e.setCapturedAt(...optional: extract from ExifSubIFDDirectory)
        ObservationEntity saved = repo.save(e);

        return new PhotoSubmissionDTO(saved.getId(), observationUploadResource.getGpsLat(), observationUploadResource.getGpsLon(), saved.getOriginalFilename());
    }

    public List<LeafletObservationDTO> getAllObservations() {
        return repo.findAll().stream().map(LeafletObservationDTO::fromEntity).toList();
    }

    @Transactional
    public void updateObservationLocation(long id, double lat, double lon) {
        var obs = repo.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Observation not found: " + id));
        obs.setLocation(createPoint(lat, lon));
    }


}
