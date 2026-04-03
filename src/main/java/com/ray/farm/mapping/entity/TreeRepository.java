package com.ray.farm.mapping.entity;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface TreeRepository extends JpaRepository<TreeEntity, Long> {

    @Query("""
            select distinct t from TreeEntity t
            join fetch t.confirmedSpecies
            join fetch t.status
            where (:speciesCode is null or t.confirmedSpecies.code = :speciesCode)
              and (:statusCode is null or t.status.code = :statusCode)
            order by t.id
            """)
    List<TreeEntity> findAllForRead(@Param("speciesCode") String speciesCode, @Param("statusCode") String statusCode);

    @Query("""
            select t from TreeEntity t
            join fetch t.confirmedSpecies
            join fetch t.status
            where t.id = :id
            """)
    Optional<TreeEntity> findByIdForRead(@Param("id") long id);

    @Query("""
            select distinct t from TreeEntity t
            join fetch t.confirmedSpecies
            join fetch t.status
            where t.id in :ids
            """)
    List<TreeEntity> findAllByIdInWithLookups(@Param("ids") Collection<Long> ids);

    @Query(value = """
            select t.id
            from tree t
            where (:speciesCode is null or t.confirmed_species_code = :speciesCode)
              and (:statusCode is null or t.status_code = :statusCode)
              and ST_DWithin(
                    t.location::geography,
                    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                    :radiusMeters
              )
            order by ST_Distance(
                    t.location::geography,
                    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
              ),
              t.id
            """, nativeQuery = true)
    List<Long> findIdsWithinRadius(@Param("lat") double lat,
                                   @Param("lon") double lon,
                                   @Param("radiusMeters") double radiusMeters,
                                   @Param("speciesCode") String speciesCode,
                                   @Param("statusCode") String statusCode);

    @Query(value = """
            select t.id
            from tree t
            where (:speciesCode is null or t.confirmed_species_code = :speciesCode)
              and (:statusCode is null or t.status_code = :statusCode)
              and ST_Intersects(
                    t.location,
                    ST_SetSRID(ST_GeomFromGeoJSON(:geometryJson), 4326)
              )
            order by t.id
            """, nativeQuery = true)
    List<Long> findIdsIntersectingGeometry(@Param("geometryJson") String geometryJson,
                                           @Param("speciesCode") String speciesCode,
                                           @Param("statusCode") String statusCode);
}
