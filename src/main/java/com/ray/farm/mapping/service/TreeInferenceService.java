package com.ray.farm.mapping.service;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ray.farm.mapping.controller.model.TreeIdentificationHealthDTO;
import com.ray.farm.mapping.controller.model.TreeIdentificationPredictionDTO;
import com.ray.farm.mapping.controller.model.TreeIdentificationPredictionItemDTO;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.util.StringUtils;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TreeInferenceService {

    private final @Qualifier("treeInferenceRestClient") RestClient restClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public TreeIdentificationHealthDTO health() {
        try {
            SidecarHealthResponse response = restClient.get()
                    .uri("/health")
                    .retrieve()
                    .body(SidecarHealthResponse.class);

            if (response == null) {
                throw unavailable("Inference service returned an empty health response.");
            }

            return new TreeIdentificationHealthDTO(
                    response.status(),
                    response.modelVersion(),
                    response.modelPath(),
                    response.labelsPath(),
                    response.backbone(),
                    response.device(),
                    response.numClasses(),
                    response.classNames(),
                    response.unknownConfidenceThreshold()
            );
        } catch (RestClientResponseException ex) {
            throw translateSidecarResponseException(ex);
        } catch (ResourceAccessException ex) {
            throw unavailable("Inference service is unavailable.");
        }
    }

    public TreeIdentificationPredictionDTO predict(MultipartFile file, int topK) throws IOException {
        if (file.isEmpty()) {
            throw badRequest("Uploaded file is empty.");
        }

        byte[] bytes = file.getBytes();
        SidecarPredictionResponse response;

        try {
            response = restClient.post()
                    .uri(uriBuilder -> uriBuilder.path("/predict").queryParam("top_k", topK).build())
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(buildMultipartBody(file, bytes))
                    .retrieve()
                    .body(SidecarPredictionResponse.class);
        } catch (RestClientResponseException ex) {
            throw translateSidecarResponseException(ex);
        } catch (ResourceAccessException ex) {
            throw unavailable("Inference service is unavailable.");
        }

        if (response == null) {
            throw unavailable("Inference service returned an empty prediction response.");
        }

        return new TreeIdentificationPredictionDTO(
                response.modelVersion(),
                response.predictions().stream()
                        .map(item -> new TreeIdentificationPredictionItemDTO(item.label(), item.confidence()))
                        .toList(),
                response.rawTopPrediction(),
                response.topPrediction(),
                response.topConfidence(),
                response.top2Margin(),
                response.isUnknown(),
                response.unknownReasons(),
                response.backbone(),
                response.device()
        );
    }

    private MultiValueMap<String, Object> buildMultipartBody(MultipartFile file, byte[] bytes) {
        HttpHeaders partHeaders = new HttpHeaders();
        partHeaders.setContentDispositionFormData("file", resolveFilename(file));
        partHeaders.setContentType(resolveMediaType(file.getContentType()));

        ByteArrayResource resource = new ByteArrayResource(bytes) {
            @Override
            public String getFilename() {
                return resolveFilename(file);
            }
        };

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", new HttpEntity<>(resource, partHeaders));
        return body;
    }

    private MediaType resolveMediaType(String contentType) {
        if (!StringUtils.hasText(contentType)) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }

        try {
            return MediaType.parseMediaType(contentType);
        } catch (IllegalArgumentException ex) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }

    private String resolveFilename(MultipartFile file) {
        return StringUtils.hasText(file.getOriginalFilename()) ? file.getOriginalFilename().trim() : "upload.bin";
    }

    private ResponseStatusException translateSidecarResponseException(RestClientResponseException ex) {
        HttpStatus status = HttpStatus.resolve(ex.getStatusCode().value());
        String detail = extractSidecarDetail(ex);

        if (status == HttpStatus.BAD_REQUEST || status == HttpStatus.UNPROCESSABLE_ENTITY) {
            return new ResponseStatusException(HttpStatus.BAD_REQUEST, detail, ex);
        }

        return new ResponseStatusException(HttpStatus.BAD_GATEWAY, detail, ex);
    }

    private String extractSidecarDetail(RestClientResponseException ex) {
        String body = ex.getResponseBodyAsString();
        if (StringUtils.hasText(body)) {
            try {
                SidecarErrorResponse error = objectMapper.readValue(body, SidecarErrorResponse.class);
                if (error != null && StringUtils.hasText(error.detail())) {
                    return error.detail();
                }
            } catch (Exception ignored) {
            }
        }

        return "Inference service request failed.";
    }

    private ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }

    private ResponseStatusException unavailable(String message) {
        return new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, message);
    }

    private record SidecarPredictionResponse(
            @JsonProperty("model_version") String modelVersion,
            @JsonProperty("predictions") List<SidecarPredictionItem> predictions,
            @JsonProperty("raw_top_prediction") String rawTopPrediction,
            @JsonProperty("top_prediction") String topPrediction,
            @JsonProperty("top_confidence") double topConfidence,
            @JsonProperty("top2_margin") double top2Margin,
            @JsonProperty("is_unknown") boolean isUnknown,
            @JsonProperty("unknown_reasons") List<String> unknownReasons,
            @JsonProperty("backbone") String backbone,
            @JsonProperty("device") String device
    ) {
    }

    private record SidecarPredictionItem(
            @JsonProperty("label") String label,
            @JsonProperty("confidence") double confidence
    ) {
    }

    private record SidecarHealthResponse(
            @JsonProperty("status") String status,
            @JsonProperty("model_version") String modelVersion,
            @JsonProperty("model_path") String modelPath,
            @JsonProperty("labels_path") String labelsPath,
            @JsonProperty("backbone") String backbone,
            @JsonProperty("device") String device,
            @JsonProperty("num_classes") int numClasses,
            @JsonProperty("class_names") List<String> classNames,
            @JsonProperty("unknown_confidence_threshold") double unknownConfidenceThreshold
    ) {
    }

    private record SidecarErrorResponse(String detail) {
    }
}
