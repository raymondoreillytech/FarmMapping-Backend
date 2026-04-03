package com.ray.farm.mapping.entity;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TreeStatusRepository extends JpaRepository<TreeStatusEntity, String> {

    List<TreeStatusEntity> findAllByActiveTrueOrderBySortOrderAscDisplayNameAsc();

    List<TreeStatusEntity> findAllByOrderBySortOrderAscDisplayNameAsc();
}
