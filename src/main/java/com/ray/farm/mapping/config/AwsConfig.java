package com.ray.farm.mapping.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.S3Presigner.Builder;

import java.net.URI;

@Configuration
public class AwsConfig {

    @Bean
    S3Client s3Client(StorageConfig storageConfig) {
        StorageConfig.S3 s3 = storageConfig.s3();
        S3ClientBuilder builder = S3Client.builder()
                .region(Region.of(s3.region()))
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(s3.forcePathStyle())
                        .build());

        if (StringUtils.hasText(s3.endpoint())) {
            builder.endpointOverride(URI.create(s3.endpoint().trim()));
        }

        return builder.build();
    }

    @Bean
    S3Presigner s3Presigner(StorageConfig storageConfig) {
        StorageConfig.S3 s3 = storageConfig.s3();
        Builder builder = S3Presigner.builder()
                .region(Region.of(s3.region()))
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(s3.forcePathStyle())
                        .build());

        if (StringUtils.hasText(s3.endpoint())) {
            builder.endpointOverride(URI.create(s3.endpoint().trim()));
        }

        return builder.build();
    }
}
