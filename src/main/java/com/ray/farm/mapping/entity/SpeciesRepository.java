package com.ray.farm.mapping.entity;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SpeciesRepository extends JpaRepository<SpeciesEntity, String> {

    List<SpeciesEntity> findAllByActiveTrueOrderBySortOrderAscDisplayNameAsc();

    List<SpeciesEntity> findAllByOrderBySortOrderAscDisplayNameAsc();
}
