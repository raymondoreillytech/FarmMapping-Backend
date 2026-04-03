package com.ray.farm.mapping.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

@ConfigurationProperties(prefix = "app.inference")
public record InferenceConfig(
        String baseUrl,
        Duration connectTimeout,
        Duration readTimeout
) {
}
