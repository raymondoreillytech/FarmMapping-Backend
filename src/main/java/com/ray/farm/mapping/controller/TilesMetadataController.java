package com.ray.farm.mapping.controller;

import com.ray.farm.mapping.controller.model.TileMetadataDto;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TilesMetadataController {

    @GetMapping("/api/tiles/metadata")
    public TileMetadataDto metadata() {

        var bounds = new TileMetadataDto.Bounds3857(
                -851043.9790, 4893580.2088,
                -850541.3878, 4894366.0692
        );

        return new TileMetadataDto(
                15,
                22,
                bounds,
                "/tiles/{z}/{x}/{y}.png"
        );
    }
}
