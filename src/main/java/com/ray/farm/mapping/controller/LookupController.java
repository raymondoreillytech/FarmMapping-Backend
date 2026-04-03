package com.ray.farm.mapping.controller;

import com.ray.farm.mapping.controller.model.SpeciesLookupDTO;
import com.ray.farm.mapping.controller.model.TreeStatusLookupDTO;
import com.ray.farm.mapping.service.LookupService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class LookupController {

    private final LookupService lookupService;

    @GetMapping("/species")
    public List<SpeciesLookupDTO> species(@RequestParam(defaultValue = "false") boolean includeInactive) {
        return lookupService.listSpecies(includeInactive);
    }

    @GetMapping("/tree-status")
    public List<TreeStatusLookupDTO> treeStatuses(@RequestParam(defaultValue = "false") boolean includeInactive) {
        return lookupService.listTreeStatuses(includeInactive);
    }
}
