package com.ray.farm.mapping.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "tree")
@Getter
@Setter
public class TreeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by_user_key", nullable = false)
    private String createdByUserKey;

    @Column(name = "updated_by_user_key", nullable = false)
    private String updatedByUserKey;

    @JdbcTypeCode(SqlTypes.INET)
    @Column(name = "created_by_ip", columnDefinition = "inet")
    private String createdByIp;

    @JdbcTypeCode(SqlTypes.INET)
    @Column(name = "updated_by_ip", columnDefinition = "inet")
    private String updatedByIp;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "confirmed_species_code", referencedColumnName = "code", nullable = false)
    private SpeciesEntity confirmedSpecies;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "status_code", referencedColumnName = "code", nullable = false)
    private TreeStatusEntity status;

    @Column(name = "notes")
    private String notes;

    @Column(name = "location", columnDefinition = "geometry(Point,4326)", nullable = false)
    private Point location;

    @OneToMany(mappedBy = "tree", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<TreePhotoEntity> photos = new ArrayList<>();

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        updatedAt = now;
        if (createdByUserKey == null || createdByUserKey.isBlank()) {
            createdByUserKey = "guest";
        }
        if (updatedByUserKey == null || updatedByUserKey.isBlank()) {
            updatedByUserKey = createdByUserKey;
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
        if (updatedByUserKey == null || updatedByUserKey.isBlank()) {
            updatedByUserKey = "guest";
        }
    }
}
