package com.ray.farm.mapping.service;

import com.ray.farm.mapping.controller.model.SpeciesLookupDTO;
import com.ray.farm.mapping.controller.model.TreeStatusLookupDTO;
import com.ray.farm.mapping.entity.SpeciesRepository;
import com.ray.farm.mapping.entity.TreeStatusRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class LookupService {

    private final SpeciesRepository speciesRepository;
    private final TreeStatusRepository treeStatusRepository;

    @Transactional(readOnly = true)
    public List<SpeciesLookupDTO> listSpecies(boolean includeInactive) {
        return (includeInactive
                ? speciesRepository.findAllByOrderBySortOrderAscDisplayNameAsc()
                : speciesRepository.findAllByActiveTrueOrderBySortOrderAscDisplayNameAsc())
                .stream()
                .map(SpeciesLookupDTO::fromEntity)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<TreeStatusLookupDTO> listTreeStatuses(boolean includeInactive) {
        return (includeInactive
                ? treeStatusRepository.findAllByOrderBySortOrderAscDisplayNameAsc()
                : treeStatusRepository.findAllByActiveTrueOrderBySortOrderAscDisplayNameAsc())
                .stream()
                .map(TreeStatusLookupDTO::fromEntity)
                .toList();
    }
}
