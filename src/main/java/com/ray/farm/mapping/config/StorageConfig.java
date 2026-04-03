package com.ray.farm.mapping.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

@ConfigurationProperties(prefix = "app.storage")
public record StorageConfig(S3 s3) {

    public record S3(
            String bucketName,
            String keyPrefix,
            String region,
            String endpoint,
            boolean forcePathStyle,
            Duration downloadUrlTtl
    ) {
    }
}
