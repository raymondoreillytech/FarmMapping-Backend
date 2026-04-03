package com.ray.farm.mapping.entity;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface TreePhotoRepository extends JpaRepository<TreePhotoEntity, Long> {

    boolean existsByTree_Id(Long treeId);

    List<TreePhotoEntity> findAllByTree_IdOrderByCreatedAtAsc(Long treeId);

    Optional<TreePhotoEntity> findByIdAndTree_Id(Long id, Long treeId);

    @Modifying
    @Query("update TreePhotoEntity p set p.primary = false where p.tree.id = :treeId and p.primary = true")
    int clearPrimaryByTreeId(@Param("treeId") long treeId);
}
