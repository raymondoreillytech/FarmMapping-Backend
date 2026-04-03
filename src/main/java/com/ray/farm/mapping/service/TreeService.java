package com.ray.farm.mapping.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ray.farm.mapping.controller.model.*;
import com.ray.farm.mapping.entity.*;
import com.ray.farm.mapping.service.PhotoStorageService.StoredPhotoObject;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class TreeService {

    private static final String UNKNOWN_SPECIES_CODE = "unknown";
    private static final String ACTIVE_STATUS_CODE = "active";
    private static final ObjectMapper JSON_MAPPER = new ObjectMapper();

    private final TreeRepository treeRepository;
    private final TreePhotoRepository treePhotoRepository;
    private final SpeciesRepository speciesRepository;
    private final TreeStatusRepository treeStatusRepository;
    private final ExifReaderService exifReaderService;
    private final PhotoStorageService photoStorageService;

    @Transactional
    public TreeEntity createTree(CreateTreeRequest request, RequestIdentity identity) {
        TreeEntity tree = new TreeEntity();
        tree.setLocation(ExifReaderService.createPoint(request.lon(), request.lat()));
        tree.setConfirmedSpecies(resolveSpeciesOrDefault(request.confirmedSpeciesCode(), UNKNOWN_SPECIES_CODE));
        tree.setStatus(resolveStatusOrDefault(request.statusCode(), ACTIVE_STATUS_CODE));
        tree.setNotes(normalizeNullableText(request.notes()));
        tree.setCreatedByUserKey(identity.userKey());
        tree.setUpdatedByUserKey(identity.userKey());
        tree.setCreatedByIp(identity.ipAddress());
        tree.setUpdatedByIp(identity.ipAddress());
        return treeRepository.save(tree);
    }

    @Transactional
    public TreeEntity updateTree(long treeId, UpdateTreeRequest request, RequestIdentity identity) {
        TreeEntity tree = treeRepository.findById(treeId)
                .orElseThrow(() -> notFound("Tree not found: " + treeId));

        boolean latProvided = request.lat() != null;
        boolean lonProvided = request.lon() != null;
        if (latProvided != lonProvided) {
            throw badRequest("lat and lon must be provided together");
        }

        if (latProvided) {
            tree.setLocation(ExifReaderService.createPoint(request.lon(), request.lat()));
        }

        if (request.confirmedSpeciesCode() != null) {
            tree.setConfirmedSpecies(resolveSpecies(request.confirmedSpeciesCode()));
        }

        if (request.statusCode() != null) {
            tree.setStatus(resolveStatus(request.statusCode()));
        }

        if (request.notes() != null) {
            tree.setNotes(normalizeNullableText(request.notes()));
        }

        tree.setUpdatedByUserKey(identity.userKey());
        tree.setUpdatedByIp(identity.ipAddress());
        return tree;
    }

    @Transactional
    public void updateTreeLocation(long treeId, double lat, double lon, RequestIdentity identity) {
        TreeEntity tree = treeRepository.findById(treeId)
                .orElseThrow(() -> notFound("Tree not found: " + treeId));
        tree.setLocation(ExifReaderService.createPoint(lon, lat));
        tree.setUpdatedByUserKey(identity.userKey());
        tree.setUpdatedByIp(identity.ipAddress());
    }

    @Transactional
    public TreePhotoEntity attachPhoto(long treeId, MultipartFile file, TreePhotoUploadMetadataRequest metadata, RequestIdentity identity) throws IOException {
        if (file.isEmpty()) {
            throw badRequest("Uploaded file is empty");
        }

        TreeEntity tree = treeRepository.findById(treeId)
                .orElseThrow(() -> notFound("Tree not found: " + treeId));

        TreePhotoUploadMetadataRequest normalizedMetadata = metadata == null ? TreePhotoUploadMetadataRequest.empty() : metadata;
        validateConfidence(normalizedMetadata.rawTopConfidence(), "rawTopConfidence");
        validateConfidence(normalizedMetadata.finalPredictionConfidence(), "finalPredictionConfidence");
        validateTopPredictions(normalizedMetadata.topPredictionsJson());

        byte[] bytes = file.getBytes();
        ExifReaderService.ExifMetadata exifMetadata;
        try {
            exifMetadata = exifReaderService.readMetadata(bytes);
        } catch (Exception ex) {
            throw badRequest("Uploaded file is not a readable image");
        }

        StoredPhotoObject storedPhoto = photoStorageService.storePhoto(
                treeId,
                file.getOriginalFilename(),
                file.getContentType(),
                bytes
        );

        try {
            boolean hasExistingPhotos = treePhotoRepository.existsByTree_Id(treeId);
            boolean makePrimary = Boolean.TRUE.equals(normalizedMetadata.isPrimary()) || !hasExistingPhotos;
            if (makePrimary) {
                treePhotoRepository.clearPrimaryByTreeId(treeId);
            }

            TreePhotoEntity photo = new TreePhotoEntity();
            photo.setTree(tree);
            photo.setOriginalFilename(file.getOriginalFilename());
            photo.setContentType(file.getContentType());
            photo.setSizeBytes(file.getSize());
            photo.setS3Bucket(storedPhoto.bucket());
            photo.setS3Key(storedPhoto.key());
            photo.setExifLocation(exifMetadata.gpsPoint());
            photo.setCapturedAt(normalizedMetadata.capturedAt() != null ? normalizedMetadata.capturedAt() : exifMetadata.capturedAt());
            photo.setUploadedByUserKey(identity.userKey());
            photo.setUploadedByIp(identity.ipAddress());
            photo.setPrimary(makePrimary);
            photo.setRawTopSpecies(resolveOptionalSpecies(normalizedMetadata.rawTopSpeciesCode()));
            photo.setRawTopConfidence(normalizedMetadata.rawTopConfidence());
            photo.setFinalPredictedSpecies(resolveFinalPredictedSpecies(normalizedMetadata));
            photo.setFinalPredictionConfidence(normalizedMetadata.finalPredictionConfidence());
            photo.setUnknownPrediction(Boolean.TRUE.equals(normalizedMetadata.unknownPrediction()));
            photo.setModelVersion(normalizeNullableText(normalizedMetadata.modelVersion()));
            photo.setTopPredictionsJson(copyJson(normalizedMetadata.topPredictionsJson()));

            return treePhotoRepository.save(photo);
        } catch (RuntimeException ex) {
            photoStorageService.deletePhoto(storedPhoto.bucket(), storedPhoto.key());
            throw ex;
        }
    }

    @Transactional(readOnly = true)
    public List<TreePhotoResponseDTO> listTreePhotos(long treeId) {
        ensureTreeExists(treeId);
        return treePhotoRepository.findAllByTree_IdOrderByCreatedAtAsc(treeId).stream()
                .map(this::toPhotoResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public TreePhotoResponseDTO getTreePhoto(long treeId, long photoId) {
        TreePhotoEntity photo = treePhotoRepository.findByIdAndTree_Id(photoId, treeId)
                .orElseThrow(() -> notFound("Tree photo not found: " + photoId + " for tree " + treeId));
        return toPhotoResponse(photo);
    }

    @Transactional(readOnly = true)
    public List<TreeEntity> listTrees(String speciesCode, String statusCode) {
        return treeRepository.findAllForRead(normalizeCode(speciesCode), normalizeCode(statusCode));
    }

    @Transactional(readOnly = true)
    public List<TreeEntity> listTreesWithinRadius(double lat, double lon, double radiusMeters, String speciesCode, String statusCode) {
        if (radiusMeters <= 0) {
            throw badRequest("radiusMeters must be greater than 0");
        }

        List<Long> ids = treeRepository.findIdsWithinRadius(lat, lon, radiusMeters, normalizeCode(speciesCode), normalizeCode(statusCode));
        return loadTreesByOrderedIds(ids);
    }

    @Transactional(readOnly = true)
    public List<TreeEntity> listTreesWithinPolygon(PolygonTreeSearchRequest request) {
        String geometryJson = normalizeGeometryJson(request.geoJson());
        List<Long> ids = treeRepository.findIdsIntersectingGeometry(
                geometryJson,
                normalizeCode(request.speciesCode()),
                normalizeCode(request.statusCode())
        );
        return loadTreesByOrderedIds(ids);
    }

    @Transactional(readOnly = true)
    public List<LeafletObservationDTO> listObservationMarkers() {
        return treeRepository.findAllForRead(null, null).stream()
                .map(LeafletObservationDTO::fromEntity)
                .toList();
    }

    @Transactional
    public void deleteTree(long treeId) {
        TreeEntity tree = treeRepository.findById(treeId)
                .orElseThrow(() -> notFound("Tree not found: " + treeId));

        List<TreePhotoEntity> photos = treePhotoRepository.findAllByTree_IdOrderByCreatedAtAsc(treeId);
        treeRepository.delete(tree);

        for (TreePhotoEntity photo : photos) {
            try {
                photoStorageService.deletePhoto(photo.getS3Bucket(), photo.getS3Key());
            } catch (RuntimeException ex) {
                log.warn("Failed to delete S3 object for removed tree photo {} from {}/{}", photo.getId(), photo.getS3Bucket(), photo.getS3Key(), ex);
            }
        }
    }

    private TreePhotoResponseDTO toPhotoResponse(TreePhotoEntity photo) {
        PhotoStorageService.StoredPhotoAccess photoAccess =
                photoStorageService.createPhotoAccess(photo.getS3Bucket(), photo.getS3Key());
        return TreePhotoResponseDTO.fromEntity(photo, photoAccess.url(), photoAccess.expiresAt());
    }

    private void ensureTreeExists(long treeId) {
        if (!treeRepository.existsById(treeId)) {
            throw notFound("Tree not found: " + treeId);
        }
    }

    private List<TreeEntity> loadTreesByOrderedIds(List<Long> ids) {
        if (ids.isEmpty()) {
            return List.of();
        }

        Map<Long, TreeEntity> treesById = new LinkedHashMap<>();
        for (TreeEntity tree : treeRepository.findAllByIdInWithLookups(ids)) {
            treesById.put(tree.getId(), tree);
        }

        return ids.stream()
                .map(treesById::get)
                .filter(java.util.Objects::nonNull)
                .toList();
    }

    private SpeciesEntity resolveSpeciesOrDefault(String requestedCode, String defaultCode) {
        return resolveSpecies(StringUtils.hasText(requestedCode) ? requestedCode : defaultCode);
    }

    private TreeStatusEntity resolveStatusOrDefault(String requestedCode, String defaultCode) {
        return resolveStatus(StringUtils.hasText(requestedCode) ? requestedCode : defaultCode);
    }

    private SpeciesEntity resolveSpecies(String code) {
        String normalizedCode = normalizeRequiredCode(code, "speciesCode");
        return speciesRepository.findById(normalizedCode)
                .orElseThrow(() -> badRequest("Unknown species code: " + normalizedCode));
    }

    private SpeciesEntity resolveOptionalSpecies(String code) {
        return StringUtils.hasText(code) ? resolveSpecies(code) : null;
    }

    private SpeciesEntity resolveFinalPredictedSpecies(TreePhotoUploadMetadataRequest metadata) {
        if (StringUtils.hasText(metadata.finalPredictedSpeciesCode())) {
            return resolveSpecies(metadata.finalPredictedSpeciesCode());
        }
        if (Boolean.TRUE.equals(metadata.unknownPrediction())) {
            return resolveSpecies(UNKNOWN_SPECIES_CODE);
        }
        return null;
    }

    private TreeStatusEntity resolveStatus(String code) {
        String normalizedCode = normalizeRequiredCode(code, "statusCode");
        return treeStatusRepository.findById(normalizedCode)
                .orElseThrow(() -> badRequest("Unknown status code: " + normalizedCode));
    }

    private String normalizeGeometryJson(JsonNode geoJson) {
        if (geoJson == null || geoJson.isNull()) {
            throw badRequest("geoJson is required");
        }

        JsonNode candidate = geoJson;
        JsonNode typeNode = geoJson.get("type");
        if (typeNode != null && "Feature".equalsIgnoreCase(typeNode.asText())) {
            candidate = geoJson.get("geometry");
        }

        if (candidate == null || candidate.isNull()) {
            throw badRequest("Polygon geometry is required");
        }

        JsonNode candidateType = candidate.get("type");
        if (candidateType == null) {
            throw badRequest("GeoJSON geometry type is required");
        }

        String type = candidateType.asText();
        if (!"Polygon".equalsIgnoreCase(type) && !"MultiPolygon".equalsIgnoreCase(type)) {
            throw badRequest("Only Polygon or MultiPolygon GeoJSON is supported");
        }

        return candidate.toString();
    }

    private String normalizeRequiredCode(String code, String fieldName) {
        String normalizedCode = normalizeCode(code);
        if (normalizedCode == null) {
            throw badRequest(fieldName + " is required");
        }
        return normalizedCode;
    }

    private String normalizeCode(String code) {
        return StringUtils.hasText(code) ? code.trim().toLowerCase() : null;
    }

    private String normalizeNullableText(String value) {
        if (!StringUtils.hasText(value)) {
            return null;
        }
        return value.trim();
    }

    private JsonNode copyJson(java.util.List<TreePredictionMetadataItemRequest> topPredictions) {
        if (topPredictions == null) {
            return null;
        }

        return JSON_MAPPER.valueToTree(topPredictions);
    }

    private void validateConfidence(Double confidence, String fieldName) {
        if (confidence != null && (confidence < 0 || confidence > 1)) {
            throw badRequest(fieldName + " must be between 0 and 1");
        }
    }

    private void validateTopPredictions(java.util.List<TreePredictionMetadataItemRequest> topPredictions) {
        if (topPredictions == null) {
            return;
        }

        for (int i = 0; i < topPredictions.size(); i++) {
            TreePredictionMetadataItemRequest item = topPredictions.get(i);
            if (item == null) {
                throw badRequest("topPredictionsJson[" + i + "] must not be null");
            }

            validateConfidence(item.confidence(), "topPredictionsJson[" + i + "].confidence");
        }
    }

    private ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }

    private ResponseStatusException notFound(String message) {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, message);
    }
}
