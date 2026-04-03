package com.ray.farm.mapping.service;

import com.ray.farm.mapping.config.StorageConfig;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class S3PhotoStorageService implements PhotoStorageService {

    private final S3Client s3Client;
    private final S3Presigner s3Presigner;
    private final StorageConfig storageConfig;

    @Override
    public StoredPhotoObject storePhoto(long treeId, String originalFilename, String contentType, byte[] bytes) throws IOException {
        String bucketName = storageConfig.s3().bucketName();
        String key = buildObjectKey(treeId, originalFilename);
        String normalizedContentType = StringUtils.hasText(contentType) ? contentType.trim() : "application/octet-stream";

        s3Client.putObject(
                PutObjectRequest.builder()
                        .bucket(bucketName)
                        .key(key)
                        .contentType(normalizedContentType)
                        .build(),
                RequestBody.fromBytes(bytes)
        );

        return new StoredPhotoObject(bucketName, key);
    }

    @Override
    public StoredPhotoAccess createPhotoAccess(String bucket, String key) {
        Duration signatureDuration = normalizeDownloadUrlTtl(storageConfig.s3().downloadUrlTtl());
        Instant expiresAt = Instant.now().plus(signatureDuration);
        String url = s3Presigner.presignGetObject(
                GetObjectPresignRequest.builder()
                        .signatureDuration(signatureDuration)
                        .getObjectRequest(GetObjectRequest.builder()
                                .bucket(bucket)
                                .key(key)
                                .build())
                        .build()
        ).url().toString();

        return new StoredPhotoAccess(url, expiresAt);
    }

    @Override
    public void deletePhoto(String bucket, String key) {
        s3Client.deleteObject(DeleteObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build());
    }

    private String buildObjectKey(long treeId, String originalFilename) {
        String prefix = storageConfig.s3().keyPrefix();
        String normalizedPrefix = StringUtils.hasText(prefix) ? prefix.trim().replaceAll("/+$", "") : "trees";
        String filename = sanitizeFilename(originalFilename);
        return normalizedPrefix + "/" + treeId + "/" + UUID.randomUUID() + "-" + filename;
    }

    private String sanitizeFilename(String originalFilename) {
        if (!StringUtils.hasText(originalFilename)) {
            return "upload.bin";
        }

        String sanitized = originalFilename.trim().replaceAll("[^A-Za-z0-9._-]", "_");
        return sanitized.isBlank() ? "upload.bin" : sanitized;
    }

    private Duration normalizeDownloadUrlTtl(Duration configuredTtl) {
        if (configuredTtl == null || configuredTtl.isZero() || configuredTtl.isNegative()) {
            return Duration.ofMinutes(15);
        }
        return configuredTtl;
    }
}
