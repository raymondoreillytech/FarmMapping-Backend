package com.ray.farm.mapping.controller;

import com.ray.farm.mapping.controller.model.LeafletObservationDTO;
import com.ray.farm.mapping.service.RequestIdentityResolver;
import com.ray.farm.mapping.service.TreeService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/observations")
public class TreeObservationsController {

    private final TreeService treeService;
    private final RequestIdentityResolver requestIdentityResolver;

    @PatchMapping(path = "/{id}/location", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Void> updateLocation(@PathVariable long id,
                                               @RequestBody LocationUpdateRequest body,
                                               HttpServletRequest request) {

        double lat = body.lat();
        double lon = body.lon();

        // minimal validation (avoid NaN/Infinity + basic GPS range)
        if (!Double.isFinite(lat) || !Double.isFinite(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
            return ResponseEntity.badRequest().build();
        }

        var identity = requestIdentityResolver.resolve(request, null);
        treeService.updateTreeLocation(id, lat, lon, identity);
        return ResponseEntity.noContent().build();
    }

    @GetMapping
    public List<LeafletObservationDTO> observations() {
        return treeService.listObservationMarkers();
    }

    public record LocationUpdateRequest(double lat, double lon) {
    }

}
