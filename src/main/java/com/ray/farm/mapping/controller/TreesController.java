package com.ray.farm.mapping.controller;

import com.ray.farm.mapping.controller.model.*;
import com.ray.farm.mapping.service.RequestIdentityResolver;
import com.ray.farm.mapping.service.TreeService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.io.IOException;
import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api/trees")
@RequiredArgsConstructor
public class TreesController {

    private final TreeService treeService;
    private final RequestIdentityResolver requestIdentityResolver;

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<TreeResponseDTO> createTree(@Valid @RequestBody CreateTreeRequest request,
                                                      HttpServletRequest servletRequest) {
        var identity = requestIdentityResolver.resolve(servletRequest, request.createdByUserKey());
        var tree = treeService.createTree(request, identity);

        URI location = ServletUriComponentsBuilder
                .fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(tree.getId())
                .toUri();

        return ResponseEntity.created(location).body(TreeResponseDTO.fromEntity(tree));
    }

    @PatchMapping(path = "/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
    public TreeResponseDTO updateTree(@PathVariable long id,
                                      @Valid @RequestBody UpdateTreeRequest request,
                                      HttpServletRequest servletRequest) {
        var identity = requestIdentityResolver.resolve(servletRequest, request.updatedByUserKey());
        return TreeResponseDTO.fromEntity(treeService.updateTree(id, request, identity));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTree(@PathVariable long id) {
        treeService.deleteTree(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping
    public List<TreeResponseDTO> listTrees(@RequestParam(required = false) String speciesCode,
                                           @RequestParam(required = false) String statusCode,
                                           @RequestParam(required = false) Double lat,
                                           @RequestParam(required = false) Double lon,
                                           @RequestParam(required = false) Double radiusMeters) {
        boolean anySpatialFilter = lat != null || lon != null || radiusMeters != null;
        if (!anySpatialFilter) {
            return treeService.listTrees(speciesCode, statusCode).stream()
                    .map(TreeResponseDTO::fromEntity)
                    .toList();
        }

        if (lat == null || lon == null || radiusMeters == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "lat, lon, and radiusMeters must be provided together"
            );
        }

        return treeService.listTreesWithinRadius(lat, lon, radiusMeters, speciesCode, statusCode).stream()
                .map(TreeResponseDTO::fromEntity)
                .toList();
    }

    @GetMapping("/{id}/photos")
    public List<TreePhotoResponseDTO> listTreePhotos(@PathVariable long id) {
        return treeService.listTreePhotos(id);
    }

    @GetMapping("/{treeId}/photos/{photoId}")
    public TreePhotoResponseDTO getTreePhoto(@PathVariable long treeId, @PathVariable long photoId) {
        return treeService.getTreePhoto(treeId, photoId);
    }

    @PostMapping(path = "/search/polygon", consumes = MediaType.APPLICATION_JSON_VALUE)
    public List<TreeResponseDTO> searchTreesWithinPolygon(@Valid @RequestBody PolygonTreeSearchRequest request) {
        return treeService.listTreesWithinPolygon(request).stream()
                .map(TreeResponseDTO::fromEntity)
                .toList();
    }

    @PostMapping(path = "/{id}/photos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<TreePhotoResponseDTO> uploadTreePhoto(@PathVariable long id,
                                                                @RequestPart("file") MultipartFile file,
                                                                @RequestPart(value = "metadata", required = false) TreePhotoUploadMetadataRequest metadata,
                                                                HttpServletRequest servletRequest) throws IOException {
        String requestedUserKey = metadata == null ? null : metadata.uploadedByUserKey();
        var identity = requestIdentityResolver.resolve(servletRequest, requestedUserKey);
        var photo = treeService.attachPhoto(id, file, metadata, identity);
        var photoResponse = treeService.getTreePhoto(id, photo.getId());

        URI location = ServletUriComponentsBuilder
                .fromCurrentRequest()
                .path("/{photoId}")
                .buildAndExpand(id, photo.getId())
                .toUri();

        return ResponseEntity.created(location).body(photoResponse);
    }
}
