package com.ray.farm.mapping.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.time.Instant;

@Entity
@Table(name = "observation")
@Data
public class ObservationEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "captured_at")
    private Instant capturedAt;

    @Column(name = "original_filename")
    private String originalFilename;

    @Column(name = "content_type")
    private String contentType;

    @Column(name = "image_bytes", nullable = false)
    @JdbcTypeCode(SqlTypes.VARBINARY)   // maps to bytea on PostgreSQL
    private byte[] imageBytes;

    @Column(name = "location", columnDefinition = "geometry(Point,4326)", nullable = false)
    private Point location;

    @Column(name = "tree_species")
    private String treeSpecies;


    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = Instant.now();
    }


    // getters/setters
}
