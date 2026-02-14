package com.ray.farm.mapping.controller;

import com.ray.farm.mapping.controller.model.TileMetadataDto;
import jakarta.validation.constraints.Min;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
public class TilesMetadataController {

    private final String tilesBaseUrl;

    public TilesMetadataController(@Value("${app.tiles.base-url}") String tilesBaseUrl) {
        this.tilesBaseUrl = trimTrailingSlash(tilesBaseUrl);
    }

    @GetMapping("/api/tiles/metadata")
    public TileMetadataDto metadata(@RequestParam @Min(1) int version) {

        var bounds = new TileMetadataDto.Bounds3857(
                -850982.990527403, 4893579.76515953,
                -850562.586871834, 4894133.9336146
        );

        var tileUrlTemplate = tilesBaseUrl + "/v" + version + "/{z}/{x}/{y}.jpg";

        return new TileMetadataDto(
                17,
                23,
                bounds,
                tileUrlTemplate
        );
    }

    private static String trimTrailingSlash(String value) {
        if (value == null) {
            return "";
        }
        var trimmed = value.trim();
        while (trimmed.endsWith("/")) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
        }
        return trimmed;
    }

}
