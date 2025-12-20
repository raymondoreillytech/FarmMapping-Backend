package com.ray.farm.mapping;

import com.ray.farm.mapping.model.LeafletObservationDTO;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api")
public class TreeGetterController {


    @GetMapping("/observations")
    public List<LeafletObservationDTO> observations() {
        return List.of(
                new LeafletObservationDTO(40.19210, -7.64230, "OakIcon", "Cork oak (0.82)"),
                new LeafletObservationDTO(40.19300, -7.64190, "PineIcon", "Pine (0.74)")
        );
    }
}


