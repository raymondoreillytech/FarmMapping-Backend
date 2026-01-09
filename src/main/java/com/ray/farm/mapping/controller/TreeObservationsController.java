package com.ray.farm.mapping.controller;

import com.drew.imaging.ImageMetadataReader;
import com.drew.imaging.ImageProcessingException;
import com.drew.metadata.Metadata;
import com.drew.metadata.exif.GpsDirectory;
import com.ray.farm.mapping.controller.model.LeafletObservationDTO;
import com.ray.farm.mapping.controller.model.PhotoSubmissionDTO;
import com.ray.farm.mapping.model.TreeSpecies;
import com.ray.farm.mapping.service.ExifReaderService;
import com.ray.farm.mapping.service.TreePhotoProcessorService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.io.IOException;
import java.net.URI;
import java.util.List;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/observations")
public class TreeObservationsController {

    private final TreePhotoProcessorService service;
    private final ExifReaderService exifReaderService;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<PhotoSubmissionDTO> create(@RequestPart("file") MultipartFile file, @RequestParam TreeSpecies treeSpecies) throws IOException, ImageProcessingException {

        if (file.isEmpty()) {
            return ResponseEntity.badRequest().build();
        }


        Metadata metadata = ImageMetadataReader.readMetadata(file.getInputStream());

        GpsDirectory gpsDir = metadata.getFirstDirectoryOfType(GpsDirectory.class);
        if (gpsDir == null || gpsDir.getGeoLocation() == null) {
            throw new IllegalStateException("No GPS EXIF in uploaded file");
        }

        double lat = gpsDir.getGeoLocation().getLatitude();
        double lon = gpsDir.getGeoLocation().getLongitude();


        var cmd = new ObservationUploadResource(
                file.getOriginalFilename(),
                file.getContentType(),
                file.getSize(),
                file.getBytes(),
                lat,
                lon,
                treeSpecies
        );

        PhotoSubmissionDTO saved = service.createFromPhoto(cmd); // saves observation to DB + extracts GPS, etc.

        URI location = ServletUriComponentsBuilder
                .fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(saved.getId())
                .toUri();

        return ResponseEntity.created(location).body(saved);
    }

    @PatchMapping(path = "/{id}/location", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Void> updateLocation(@PathVariable long id,
                                               @RequestBody LocationUpdateRequest body) {

        double lat = body.lat();
        double lon = body.lon();

        // minimal validation (avoid NaN/Infinity + basic GPS range)
        if (!Double.isFinite(lat) || !Double.isFinite(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
            return ResponseEntity.badRequest().build();
        }

        service.updateObservationLocation(id, lat, lon); // implement in service
        return ResponseEntity.noContent().build(); // 204
    }

    @GetMapping
    public List<LeafletObservationDTO> observations() {

        return service.getAllObservations();
    }

    // minimal DTO (can be record)
    public record LocationUpdateRequest(double lat, double lon) {
    }

}
