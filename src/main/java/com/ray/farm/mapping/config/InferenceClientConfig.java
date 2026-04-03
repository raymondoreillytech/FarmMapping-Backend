package com.ray.farm.mapping.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

@Configuration
public class InferenceClientConfig {

    @Bean("treeInferenceRestClient")
    RestClient treeInferenceRestClient(InferenceConfig inferenceConfig) {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout((int) inferenceConfig.connectTimeout().toMillis());
        requestFactory.setReadTimeout((int) inferenceConfig.readTimeout().toMillis());

        return RestClient.builder()
                .baseUrl(inferenceConfig.baseUrl())
                .requestFactory(requestFactory)
                .build();
    }
}
