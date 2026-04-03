package com.ray.farm.mapping.controller.model;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ray.farm.mapping.entity.TreePhotoEntity;

import java.time.Instant;
import java.util.List;

public record TreePhotoResponseDTO(
        long id,
        long treeId,
        String s3Bucket,
        String s3Key,
        String originalFilename,
        String contentType,
        long sizeBytes,
        Instant createdAt,
        Instant capturedAt,
        Double exifLat,
        Double exifLon,
        boolean primary,
        String rawTopSpeciesCode,
        Double rawTopConfidence,
        String finalPredictedSpeciesCode,
        Double finalPredictionConfidence,
        boolean unknownPrediction,
        String modelVersion,
        List<TreePredictionMetadataItemDTO> topPredictionsJson,
        String downloadUrl,
        Instant downloadUrlExpiresAt
) {

    private static final ObjectMapper JSON_MAPPER = new ObjectMapper();
    private static final TypeReference<List<TreePredictionMetadataItemDTO>> TOP_PREDICTIONS_TYPE =
            new TypeReference<>() {
            };

    public static TreePhotoResponseDTO fromEntity(TreePhotoEntity photo) {
        return fromEntity(photo, null, null);
    }

    public static TreePhotoResponseDTO fromEntity(TreePhotoEntity photo, String downloadUrl, Instant downloadUrlExpiresAt) {
        return new TreePhotoResponseDTO(
                photo.getId(),
                photo.getTree().getId(),
                photo.getS3Bucket(),
                photo.getS3Key(),
                photo.getOriginalFilename(),
                photo.getContentType(),
                photo.getSizeBytes(),
                photo.getCreatedAt(),
                photo.getCapturedAt(),
                photo.getExifLocation() == null ? null : photo.getExifLocation().getY(),
                photo.getExifLocation() == null ? null : photo.getExifLocation().getX(),
                photo.isPrimary(),
                photo.getRawTopSpecies() == null ? null : photo.getRawTopSpecies().getCode(),
                photo.getRawTopConfidence(),
                photo.getFinalPredictedSpecies() == null ? null : photo.getFinalPredictedSpecies().getCode(),
                photo.getFinalPredictionConfidence(),
                photo.isUnknownPrediction(),
                photo.getModelVersion(),
                photo.getTopPredictionsJson() == null ? null : JSON_MAPPER.convertValue(photo.getTopPredictionsJson(), TOP_PREDICTIONS_TYPE),
                downloadUrl,
                downloadUrlExpiresAt
        );
    }
}
