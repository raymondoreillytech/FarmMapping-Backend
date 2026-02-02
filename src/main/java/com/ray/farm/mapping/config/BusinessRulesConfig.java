package com.ray.farm.mapping.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ConfigurationProperties(prefix = "app.business-rules")
public record BusinessRulesConfig(
    List<String> allowedSpecies
) {}
