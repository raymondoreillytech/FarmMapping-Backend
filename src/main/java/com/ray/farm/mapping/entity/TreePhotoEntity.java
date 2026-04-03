package com.ray.farm.mapping.entity;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.time.Instant;

@Entity
@Table(name = "tree_photo")
@Getter
@Setter
public class TreePhotoEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tree_id", nullable = false)
    private TreeEntity tree;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "captured_at")
    private Instant capturedAt;

    @Column(name = "original_filename")
    private String originalFilename;

    @Column(name = "content_type")
    private String contentType;

    @Column(name = "size_bytes", nullable = false)
    private long sizeBytes;

    @Column(name = "s3_bucket", nullable = false)
    private String s3Bucket;

    @Column(name = "s3_key", nullable = false)
    private String s3Key;

    @Column(name = "exif_location", columnDefinition = "geometry(Point,4326)")
    private Point exifLocation;

    @Column(name = "uploaded_by_user_key", nullable = false)
    private String uploadedByUserKey;

    @JdbcTypeCode(SqlTypes.INET)
    @Column(name = "uploaded_by_ip", columnDefinition = "inet")
    private String uploadedByIp;

    @Column(name = "is_primary", nullable = false)
    private boolean primary;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "raw_top_species_code", referencedColumnName = "code")
    private SpeciesEntity rawTopSpecies;

    @Column(name = "raw_top_confidence")
    private Double rawTopConfidence;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "final_predicted_species_code", referencedColumnName = "code")
    private SpeciesEntity finalPredictedSpecies;

    @Column(name = "final_prediction_confidence")
    private Double finalPredictionConfidence;

    @Column(name = "is_unknown_prediction", nullable = false)
    private boolean unknownPrediction;

    @Column(name = "model_version")
    private String modelVersion;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "top_predictions_json", columnDefinition = "jsonb")
    private JsonNode topPredictionsJson;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (uploadedByUserKey == null || uploadedByUserKey.isBlank()) {
            uploadedByUserKey = "guest";
        }
    }

    @PreUpdate
    void onUpdate() {
        if (uploadedByUserKey == null || uploadedByUserKey.isBlank()) {
            uploadedByUserKey = "guest";
        }
    }
}
