package com.ray.farm.mapping.controller;

import com.ray.farm.mapping.controller.model.TileMetadataDto;
import jakarta.validation.constraints.Min;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
public class TilesMetadataController {

    @GetMapping("/api/tiles/metadata")
    public TileMetadataDto metadata(@RequestParam @Min(1) int version) {

        var bounds = new TileMetadataDto.Bounds3857(
                -851043.9790, 4893580.2088,
                -850541.3878, 4894366.0692
        );

        return new TileMetadataDto(
                15,
                22,
                bounds,
                "http://localhost:4566/farmmapping-map-tiles-local/v" + version + "/{z}/{x}/{y}.png"
        );
    }

}
