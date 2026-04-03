package com.ray.farm.mapping.controller;

import com.ray.farm.mapping.controller.model.TreeIdentificationHealthDTO;
import com.ray.farm.mapping.controller.model.TreeIdentificationPredictionDTO;
import com.ray.farm.mapping.service.TreeInferenceService;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@Validated
@RestController
@RequestMapping("/api/tree-identification")
@RequiredArgsConstructor
public class TreeIdentificationController {

    private final TreeInferenceService treeInferenceService;

    @GetMapping("/health")
    public TreeIdentificationHealthDTO health() {
        return treeInferenceService.health();
    }

    @PostMapping(path = "/predict", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public TreeIdentificationPredictionDTO predict(@RequestPart("file") MultipartFile file,
                                                   @RequestParam(defaultValue = "3") @Min(1) @Max(10) int topK) throws IOException {
        return treeInferenceService.predict(file, topK);
    }
}
