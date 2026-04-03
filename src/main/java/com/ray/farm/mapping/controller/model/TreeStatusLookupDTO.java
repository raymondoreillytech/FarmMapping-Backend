package com.ray.farm.mapping.controller.model;

import com.ray.farm.mapping.entity.TreeStatusEntity;

public record TreeStatusLookupDTO(
        String code,
        String displayName,
        boolean active,
        int sortOrder
) {

    public static TreeStatusLookupDTO fromEntity(TreeStatusEntity status) {
        return new TreeStatusLookupDTO(
                status.getCode(),
                status.getDisplayName(),
                status.isActive(),
                status.getSortOrder()
        );
    }
}
